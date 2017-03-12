require 'sinatra'
require "sinatra/json"
require 'json'
require 'thin'
require 'secure_headers'
require 'lru_redux'

configure do
  use SecureHeaders::Middleware

  SecureHeaders::Configuration.default do |config|
    # 20 seconds
    config.hsts = "max-age=#{630720000}; includeSubdomains"
    config.x_frame_options = "DENY"
    config.csp = {
     default_src: %w('self' https://razorpay.com),
     script_src: %w('none'),
     object_src: %w('none'),
     font_src: %w('self' https://fonts.gstatic.com),
     style_src: %w('self' 'unsafe-inline' https://fonts.googleapis.com)
   } 
 end

  set :bind, '0.0.0.0'
  set :protection, :except => [:json_csrf]
  if production?
    require 'secure_headers'
    require 'rack/ssl-enforcer'
    use SecureHeaders::Middleware
    use Rack::SslEnforcer
  end
  set :server, "thin"
  set :ifsc_codes, LruRedux::TTL::Cache.new(50, 20 * 60)
end

helpers do
  def ifsc_data(code)
    return nil if !code
    code = code.upcase
    bank = code[0...4]
    unless settings.ifsc_codes.key?(bank)
      bank_data = JSON.parse File.read "data/#{bank}.json"
      settings.ifsc_codes[bank] = bank_data if bank_data
     end
    bank_data = settings.ifsc_codes[bank]
    data = bank_data[code] if bank_data
    data
  end
end

get '/' do
  readme = File.read 'README.md'
  erb :index, :locals => { :text => markdown(readme) }
end

get '/:code' do
  begin
    data = ifsc_data(params['code'])
    puts data
    return json data if data
    status 404
    json "Not Found"
  rescue Exception => e
    puts e
    status 404
    json "Not Found"
  end
end

get '/.well-known/acme-challenge/T5AjpABdcHcA89HCbaGVuoD50UEnwYbcXCITQoUFFpk' do
  return 'T5AjpABdcHcA89HCbaGVuoD50UEnwYbcXCITQoUFFpk.KE2Tu85zyb88P7GUnGf_JARVNRc9BtLFJQttAao908U'
end