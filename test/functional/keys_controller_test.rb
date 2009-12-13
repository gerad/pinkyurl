require 'test_helper'

class KeysControllerTest < ActionController::TestCase
  test "create" do
    assert_difference 'Key.count' do
      post :create, :format => 'json'
      assert_response :created
    end
  end

  test "create key takes no parameters" do
    post :create, :key => { :value => 1 }, :format => 'xml'
    assert_response :created
    assert_not_equal 1, assigns(:key).value
    assert_select 'value', :text => assigns(:key).value
  end
end
