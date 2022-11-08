# frozen_string_literal: true

require 'sinatra'
require 'redis'
require 'thin'
require 'json'
require 'ifsc'
require './metrics'
require 'secure_headers'
require 'daru'

#load the dataframe on server start
$df = Daru::DataFrame.from_csv("IFSC.csv")

class IFSCPlus < Razorpay::IFSC::IFSC
  # Returns a 4 character known code for a bank
  # TODO: Move this method to the ifsc.rb script
  # in next release
  class << self
    def get_bank_code(code)
      sublet_code = sublet_data[code]
      regular_code = code[0..3].upcase

      custom_sublet_data.each do |prefix, value|
        return value if (prefix == code[0..prefix.length - 1]) && (value.length == 4)
      end
      sublet_code || regular_code
    end

    # Gets details of banks given the bank name,
    # city and state
    def filter_banks(state = nil, city = nil, bank = nil, limit = nil, offset = nil)

      filtered_df = $df

      unless state.nil?
        filtered_df = filtered_df.where(filtered_df["STATE"].eq(state))
      end

      unless city.nil?
        filtered_df = filtered_df.where(filtered_df["CITY"].eq(city))
      end

      unless bank.nil?
        filtered_df = filtered_df.where(filtered_df["BANK"].eq(bank))
      end

      # default limit is 10
      # minimum limit is 1
      # maximum limit is 100
      if limit.nil?
        limit = 10
      else
        limit = [[Integer(limit),1].max(),100].min()
      end
      
      # default and minimum offset is 0
      # maximum offset is size of filtered_df
      if offset.nil?
        offset = 0
      else
        offset = [[Integer(offset),0].max(),filtered_df.size].min()
      end

      paginated_df = filtered_df.row[offset..offset+limit-1]

      result = Hash.new
      result["data"] = JSON.parse(paginated_df.to_json)
      result["hasNext"] = limit + offset < filtered_df.size
      result["count"] = filtered_df.size

      return result
    end
  end
end

configure do
  use SecureHeaders::Middleware

  SecureHeaders::Configuration.default do |config|
    # 20 seconds
    config.hsts = 'max-age=630720000; includeSubdomains'
    config.x_frame_options = 'DENY'
    config.csp = {
      img_src: %w[https://cdn.razorpay.com https://razorpay.com https://www.google-analytics.com https://stats.g.doubleclick.net],
      default_src: %w['self' https://razorpay.com],
      script_src: %w['self' https://www.google-analytics.com],
      object_src: %w['none'],
      font_src: %w['self' https://fonts.gstatic.com],
      style_src: %w['self' 'unsafe-inline' https://fonts.googleapis.com]
    }
  end

  set :bind, '0.0.0.0'
  set :protection, except: [:json_csrf]
  if production?
    require 'secure_headers'
    require 'rack/ssl-enforcer'
    use SecureHeaders::Middleware
    use Rack::SslEnforcer
  end
  set :redis, Redis.new
  set :server, 'thin'
  set :metrics, Metrics.new
end

helpers do
  def bank_details(branch)
    bank_code = IFSCPlus.get_bank_code(branch)

    [IFSCPlus.bank_name_for(branch), bank_code]
  end

  def strtobool(str)
    case str
    when 'true'
      true
    when 'false'
      false
    else
      false
    end
  end

  def maybestr(str)
    return nil if str.empty?

    str
  end

  def ifsc_data(code)
    return nil unless code

    code = code.upcase
    data = settings.redis.hgetall code

    if !data.empty?
      data['BANK'], data['BANKCODE'] = bank_details(code)
      data['IFSC'] = code
      data['RTGS'] = strtobool data['RTGS']
      data['NEFT'] = strtobool data['NEFT']
      data['IMPS'] = strtobool data['IMPS']
      data['UPI'] = strtobool data['UPI']
      data['MICR'] = maybestr data['MICR']
      data['SWIFT'] = maybestr data['SWIFT']
      settings.metrics.increment code
    else
      data = nil
    end
    data
  end
end

get '/' do
  readme = File.read 'README.md'
  erb :index, locals: { text: markdown(readme) }
end

get '/search' do
  content_type :json
  data = IFSCPlus.filter_banks(params['state'], params['city'], params['bank'], params['limit'], params['offset'])
  return data.to_json
# to prevent any errors from non integer limit and offset when converted from string 
rescue ArgumentError => e
    puts e
    status 400
    'Invalid integer for limit or offset'.to_json
end

get '/metrics' do
  settings.metrics.format
end

get '/:code' do
  data = ifsc_data(params['code'])
  headers(
    'Access-Control-Allow-Origin' => '*',
    'Content-Type' => 'application/json'
  )
  return data.to_json if data

  status 404
  'Not Found'.to_json
rescue StandardError => e
  puts e
  status 404
  'Not Found'.to_json
end
