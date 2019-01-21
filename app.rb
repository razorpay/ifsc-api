require 'sinatra'
require 'redis'
require 'thin'
require 'json'
require 'ifsc'
require './metrics'
require 'sinatra/json'
require "sinatra/multi_route"
require 'secure_headers'

class IFSCPlus < Razorpay::IFSC::IFSC
  # Returns a 4 character known code for a bank
  # TODO: Move this method to the ifsc.rb script
  # in next release
  class << self
    def get_bank_code(code)
      sublet_code = sublet_data[code]
      regular_code = code[0..3].upcase

      custom_sublet_data.each do |prefix, value|
        if (prefix == code[0..prefix.length - 1]) && (value.length == 4)
          return value
        end
      end
      sublet_code || regular_code
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

  def ifsc_data(code)
    return nil unless code
    code = code.upcase
    data = settings.redis.hgetall code

    if !data.empty?

      encoding_options = {
        :invalid           => :replace,  # Replace invalid byte sequences
        :undef             => :replace,  # Replace anything not defined in ASCII
        :replace           => '',        # Use a blank for those replacements
        :universal_newline => true       # Always break lines with \n
      }

      data['PINCODE'] = nil
      data['ADDRESS'] = data['ADDRESS'].encode(Encoding.find('ASCII'), encoding_options)
      data['BANK'], data['BANKCODE'] = bank_details(code)
      data['IFSC'] = code
      data['RTGS'] = strtobool data['RTGS']
      data['NEFT'] = strtobool data['NEFT']
      data['IMPS'] = strtobool data['IMPS']
      data['UPI'] = strtobool data['UPI']

      if data['ADDRESS'] =~ /(\d{6})/
        data['PINCODE'] = data['ADDRESS'].match /(\d{6})/
      end

      settings.metrics.increment code
    else
      data = nil
    end
    data
  end
end

get '/' do
  erb :index
end

get '/metrics' do
  settings.metrics.format
end

get '/:code.html', %r{/[\w-]+/[\w-]+/(?<code>[A-Z0-9]{11})} do
  begin
    data = ifsc_data(params['code'])
    erb :ifsc, locals: { data: data }
  rescue StandardError => e
    puts e
    status 404
    json 'Not Found'
  end
end

get '/:code' do
  begin
    data = ifsc_data(params['code'])
    headers(
      'Access-Control-Allow-Origin' => '*'
    )
    return json data if data
    status 404
    json 'Not Found'
  rescue StandardError => e
    puts e
    status 404
    json 'Not Found'
  end
end
