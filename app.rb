require 'sinatra'
require "sinatra/json"
require 'json'
require 'thin'

configure do
  set :bind, '0.0.0.0'
  set :protection, :except => [:json_csrf]
  if production?
    require 'rack/ssl-enforcer'
    use Rack::SslEnforcer
  end
  set :server, "thin"
end

get '/' do
  readme = File.read 'README.md'
  erb :index, :locals => { :text => markdown(readme) }
end

get '/:code' do
  begin
    code = params['code']
    bank = code[0...4]
    data = JSON.parse File.read "data/#{bank}.json"
    data = data[code]
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