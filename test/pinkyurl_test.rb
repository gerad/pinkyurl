require 'pinkyurl'
require 'test/unit'
require 'rack/test'

set :environment, :test

class PinkyurlTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app; Sinatra::Application end

  def test_index
    get '/'
    assert last_response.ok?
    assert last_response.body[/form/]
  end

  def test_get_invalid_url
    get '/i', :url => 'foo'
    assert last_response.ok?
    assert_equal 'invalid url', last_response.body
  end

  def test_get_url
    get '/i', :url => 'http://google.com'
    assert last_response.ok?
  end
end
