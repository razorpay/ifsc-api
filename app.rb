# frozen_string_literal: true

require 'sinatra'
require 'redis'
require 'thin'
require 'json'
require 'ifsc'
require './metrics'
require 'secure_headers'
require 'daru'


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
    def filter_banks(state = nil, city = nil, bankcode = nil, branch = nil, limit = nil, offset = nil)

      filtered_df = $df

      unless state.nil?
        filtered_df = filtered_df.where(filtered_df["ISO3166"].eq(state))
      end

      unless city.nil?
        filtered_df = filtered_df.where(filtered_df["CITY"].eq(city))
      end

      unless bankcode.nil?
        filtered_df = filtered_df.where(filtered_df["BANKCODE"].eq(bankcode))
      end

      unless branch.nil?
        filtered_df = filtered_df.where(filtered_df["BRANCH"].eq(branch))
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

      if filtered_df.size == 1
        paginated_df = filtered_df
      elsif offset == offset+limit-1
        # queries like row[0..0] returns a Daru::Vector not a Daru::DataFrame
        paginated_df = filtered_df.row[offset..offset+limit].first(1)
      else
        paginated_df = filtered_df.row[offset..offset+limit-1]
      end

      result = {"data" => paginated_df.to_a[0]}
      result["hasNext"] = limit + offset < filtered_df.size
      result["count"] = filtered_df.size

      return result
    end

    def get_states(bankcode)
      filtered_df = $df.where($df["BANKCODE"].eq(bankcode))

      result = {"state" => filtered_df["STATE"].uniq.to_a}
      return result
    end

    def get_districts(state, bankcode)
      filtered_df = $df.where($df["ISO3166"].eq(state) & $df["BANKCODE"].eq(bankcode))

      result = {"district" => filtered_df["DISTRICT"].uniq.to_a}
      return result

    end


    def get_branches(bankcode, state, district)
      filtered_df = $df.where($df["BANKCODE"].eq(bankcode) & $df["ISO3166"].eq(state) & $df["DISTRICT"].eq(district))

      result = {"branch" => filtered_df["BRANCH"].uniq.to_a}
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
  return nil if str.nil?
  return nil if str.empty?

  str
end

helpers do
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


def load_df()

  redis = Redis.new

  # Need to wait before sending a command to the redis server
  sleep(10)

  keys = redis.keys("*")

  arr_keys = ["BANK", "IFSC", "BRANCH", "CENTRE", "DISTRICT", "STATE", "ADDRESS", "CONTACT", "IMPS", "RTGS", "CITY", "ISO3166", "NEFT", "MICR", "UPI", "SWIFT", "BANKCODE"]

  dataframe_args = Hash.new

  arr_keys.each do |key|
    dataframe_args[key] = []
  end

  keys.each_with_index do |ifsc, index|
    
    if ifsc.match(/^[A-Z]{4}0[A-Z0-9]{6}$/)

        lib_bank_details = bank_details(ifsc)

        detail = redis.hgetall(ifsc)
        
        dataframe_args["BANK"].append(lib_bank_details[0])
        dataframe_args["BANKCODE"].append(lib_bank_details[1])
        dataframe_args["IMPS"].append(strtobool(detail["IMPS"]))
        dataframe_args["NEFT"].append(strtobool(detail["NEFT"]))
        dataframe_args["ADDRESS"].append(detail["ADDRESS"])
        dataframe_args["SWIFT"].append(maybestr(detail["SWIFT"]))
        dataframe_args["ISO3166"].append(detail["ISO3166"])
        dataframe_args["UPI"].append(strtobool(detail["UPI"]))
        dataframe_args["STATE"].append(detail["STATE"])
        dataframe_args["MICR"].append(maybestr(detail["MICR"]))
        dataframe_args["CONTACT"].append(detail["CONTACT"])
        dataframe_args["CITY"].append(detail["CITY"])
        dataframe_args["BRANCH"].append(detail["BRANCH"])
        dataframe_args["DISTRICT"].append(detail["DISTRICT"])
        dataframe_args["RTGS"].append(strtobool(detail["RTGS"]))
        dataframe_args["CENTRE"].append(detail["CENTRE"])
        dataframe_args["IFSC"].append(ifsc)

    end

    if (index + 1) % 1000 == 0
        puts "Processed #{index + 1} entries"
    end
    
  end

  $df = Daru::DataFrame.new(dataframe_args)

end

load_df()


get '/' do
  readme = File.read 'README.md'
  erb :index, locals: { text: markdown(readme) }
end

get '/search' do
  content_type :json
  data = IFSCPlus.filter_banks(params['state'], params['city'], params['bankcode'], params['branch'], params['limit'], params['offset'])
  return JSON.generate(data)
# to prevent any errors from non integer limit and offset when converted from string 
rescue ArgumentError => e
    puts e
    status 400
    'Invalid integer for limit or offset'.to_json
end

get '/metrics' do
  settings.metrics.format
end

get '/results' do
  content_type :json

  if params['bankcode'] != nil && params['state'].nil? && params['district'].nil?
    data = IFSCPlus.get_states(params['bankcode'])
    return JSON.generate(data)

  elsif params['bankcode'] != nil && params['state'] != nil && params['district'].nil?
    data = IFSCPlus.get_districts(params['state'],params['bankcode'])
    return JSON.generate(data)
  
  elsif params['bankcode'] != nil && params['state'] != nil && params['district'] != nil
    data = IFSCPlus.get_branches(params['bankcode'], params['state'], params['district'])
    return JSON.generate(data)
  else
    status 400
  end
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
