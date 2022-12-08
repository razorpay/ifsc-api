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
    get '/search?city=BANGALORE&offset=0&bankcode=HDFC&limit=100&branch=THE AGS EMPLOYEES COOP BANK LTD&state=IN-KA'
    data = JSON.parse last_response.body
    assert_equal data, JSON.parse(File.read 'test/search.json')
  end

  def test_states_response
    get '/places?bankcode=AUBL'
    data = JSON.parse last_response.body
    assert_equal data["states"].sort, JSON.parse(File.read 'test/states.json')["states"].sort
  end

  def test_districts_response
    get '/places?state=IN-KA&bankcode=AUBL'
    data = JSON.parse last_response.body
    assert_equal data["districts"].sort, JSON.parse(File.read 'test/districts.json')["districts"].sort
  end

  def test_branches_response
    get '/places?state=IN-KA&district=BANGLORE&bankcode=AUBL'
    data = JSON.parse last_response.body
    assert_equal data["branches"].sort, JSON.parse(File.read 'test/branches.json')["branches"].sort
  end
end
