require 'test_helper'

class KickTheTiresTest < ActionController::IntegrationTest
  fixtures :all

  def teardown
    SystemMock.teardown
  end

  test "check out pinkyurl" do
    get "/"
    assert_response :ok
    assert_select 'form'

    get '/i', :url => 'http://foo.com', :key => 'abc123'
    assert_response :ok
  end
end
