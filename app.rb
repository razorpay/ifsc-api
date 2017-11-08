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
     img_src: %w(https://cdn.razorpay.com),
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
  set :ifsc_codes, LruRedux::TTL::Cache.new(25, 20 * 60)
  set :bank_names, JSON.parse(File.read 'data/banknames.json')
  set :sublet_list, JSON.parse(File.read 'data/sublet.json')
end

helpers do

  def bank_name(branch)
    bank_code = nil
    if settings.sublet_list.key? branch
      bank_code = settings.sublet_list[branch]
    else
      bank_code = branch[0...4]
    end

    settings.bank_names[bank_code]
  end

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

    data['BANK'] = bank_name(code)

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
    headers({
      'Access-Control-Allow-Origin' => '*'
    })
    return json data if data
    status 404
    json "Not Found"
  rescue Exception => e
    puts e
    status 404
    json "Not Found"
  end
end