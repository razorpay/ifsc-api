require "test/unit"
require "rack/test"
require "json"

OUTER_APP = Rack::Builder.parse_file("config.ru").first

class TestApp < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def test_root
    get "/"
    assert last_response.ok?
  end

  def test_ifsc_response
    get '/HDFC0CAGSBK'
    data = JSON.parse last_response.body
    h = last_response.headers
    assert last_response.ok?
    assert h['Access-Control-Allow-Origin'] == '*'
    assert h['Content-Type'] == 'application/json'
    assert h['X-XSS-Protection'] == '1; mode=block'
    assert_equal data, JSON.parse(File.read 'test/HDFC0CAGSBK.json')
  end

  def test_search_response
    get '/search?limit=1&offset=0'
    data = JSON.parse last_response.body
    assert_equal data, JSON.parse(File.read 'test/search.json')
  end
end
