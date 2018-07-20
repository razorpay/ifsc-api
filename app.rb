require 'sinatra'
require 'redis'
require 'thin'
require 'json'
require './metrics'
require 'sinatra/json'
require 'secure_headers'

configure do
  use SecureHeaders::Middleware

  SecureHeaders::Configuration.default do |config|
    # 20 seconds
    config.hsts = 'max-age=630720000; includeSubdomains'
    config.x_frame_options = 'DENY'
    config.csp = {
      img_src: %w[https://cdn.razorpay.com https://razorpay.com],
      default_src: %w['self' https://razorpay.com],
      script_src: %w['none'],
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
  set :bank_names, JSON.parse(File.read('data/banknames.json'))
  set :sublet_list, JSON.parse(File.read('data/sublet.json'))
  set :metrics, Metrics.new
end

helpers do
  def bank_details(branch)
    bank_code = if settings.sublet_list.key? branch
                  settings.sublet_list[branch]
                else
                  branch[0...4]
                end

    [settings.bank_names[bank_code], bank_code]
  end

  def ifsc_data(code)
    return nil unless code
    code = code.upcase
    data = settings.redis.hgetall code

    if !data.empty?
      data['BANK'], data['BANKCODE'] = bank_details(code)
      data['IFSC'] = code
      data['RTGS'] = true if data.key? 'RTGS'
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

get '/metrics' do
  settings.metrics.format
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
