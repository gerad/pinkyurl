require 'test_helper'

class PeopleControllerTest < ActionController::TestCase
  setup :activate_authlogic

  test "should not get index" do
    assert_raise ActionController::UnknownAction do
      get :index
    end
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create person" do
    assert_difference('Person.count') do
      post :create, :person => {
        :email => 'three@three.com',
        :password => 'password3',
        :password_confirmation => 'password3' }
    end

    assert_redirected_to person_path(assigns(:person))
  end

  test "should show person" do
    assert_raise SecurityError do
      get :show, :id => people(:one).to_param
    end

    PersonSession.create people(:one)
    get :show, :id => people(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    assert_raise SecurityError do
      get :edit, :id => people(:one).to_param
    end

    PersonSession.create people(:one)
    get :edit, :id => people(:one).to_param
    assert_response :success
  end

  test "should update person" do
    assert_raise SecurityError do
      put :update, :id => people(:one).to_param, :person => { }
    end

    PersonSession.create people(:one)
    put :update, :id => people(:one).to_param, :person => { }
    assert_redirected_to person_path(assigns(:person))
  end

  test "should destroy person" do
    assert_raise SecurityError do
      delete :destroy, :id => people(:one).to_param
    end

    PersonSession.create people(:one)
    assert_difference('Person.count', -1) do
      delete :destroy, :id => people(:one).to_param
    end

    assert_redirected_to people_path
  end
end
