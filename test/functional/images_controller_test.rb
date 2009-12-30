require 'test_helper'

class ImagesControllerTest < ActionController::TestCase
  def teardown
    SystemMock.teardown
  end

  test "get invalid urls" do
    %w( foo file:///etc/passwd http://.com ).each do |url|
      get :index, :url => url, :key => 'abc123'
      assert_response :unprocessable_entity
      assert_equal 'invalid url', @response.body, url
    end
  end

  test "get url" do
    get :index, :url => 'http://google.com', :key => 'abc123'
    assert_response :ok
    assert_equal 'CutyCapt', SystemMock.args.shift
    assert SystemMock.args.include?('--url=http://google.com')
  end

  test "invalid key" do
    assert_raise SecurityError do
      get :index, :url => 'http://google.com', :key => 'ABd123'
    end

    assert_raise SecurityError do
      get :index, :url => 'http://google.com'
    end
  end

  test "self referer bypasses key" do
    @request.env['HTTP_REFERER'] = @request.url
    get :index, :url => 'http://google.com'
    assert_response :ok
  end

  test "crop" do
    get :index, :url => 'http://google.com', :crop => '50x50', :key => 'abc123'
    assert_response :ok
  end

  test "extra args" do
    get :index, :url => 'http://google.com', 'out-format' => 'svg', :key => 'abc123'
    assert_response :ok
    assert_equal 'CutyCapt', SystemMock.args.shift
    assert SystemMock.args.include?('--out-format=svg')
  end

  test "args" do
    defaults = %w/ --out-format=png --delay=1000 --min-width=1024 /
    defaults.push "--user-styles=file://#{Pathname.new('public/stylesheets/cutycapt.css').realpath}"
    defaults.push "--max-wait=5000"

    # valid ones
    assert_equal((defaults + %w/--out='foo;/).sort, @controller.send(:args,'out' => "'foo;").sort)

    # invalid ones
    assert_equal(defaults.sort, @controller.send(:args, 'eofijout' => "'foo;").sort)
    assert_equal(defaults.sort, @controller.send(:args, 'max-wait' => 0).sort)
    assert_equal(defaults.sort, @controller.send(:args, 'user-styles' => 'file:///etc/passwd').sort)
  end

  test "keep track of polaroids" do
    assert_difference 'Image.count' do
      @request.env['HTTP_REFERER'] = @request.url
      post :create, :url => 'http://google.com', :key => 'abc123'
      assert_equal 'http://google.com', Image.last.url
    end

    assert_difference 'Image.count', 0 do
      post :create, :url => 'http://google.com', :key => 'abc123'
    end

    assert_difference 'Image.count', 0 do
      post :create, :url => 'blah', :key => 'abc123'
    end
  end
end
