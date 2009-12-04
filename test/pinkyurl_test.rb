require 'pinkyurl'
require 'test/unit'
require 'rack/test'
require 'ruby-debug'

set :environment, :test

def system *args
  PinkyurlTest.args = args
  if file = args.find { |a| a.match /^--out=(.*)/ } && $1
    FileUtils.mkdir_p File.dirname(file)
    FileUtils.touch file
  end
  true
end

class PinkyurlTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app; Sinatra::Application end

  def self.args= a; @args = a end
  def self.args; @args end

  def setup
    @wd = FileUtils.pwd
    FileUtils.cd File.dirname(__FILE__)
    PinkyurlTest.args = nil
  end

  def teardown
    FileUtils.cd @wd
    FileUtils.rm_r File.dirname(__FILE__) + '/public/cache', :force => true
  end

  def test_index
    get '/'
    assert last_response.ok?
    assert last_response.body[/form/]
  end

  def test_stylesheet
    get '/stylesheets/application.css'
    assert last_response.ok?
    assert last_response.body[/body/]
  end

  def test_get_invalid_urls
    %w( foo file:///etc/passwd http://.com ).each do |url|
      get '/i', :url => url
      assert last_response.ok?
      assert_equal 'invalid url', last_response.body, url
    end
  end

  def test_get_url
    get '/i', :url => 'http://google.com'
    assert last_response.ok?
    assert_equal 'CutyCapt', PinkyurlTest.args.shift
    assert PinkyurlTest.args.include?('--url=http://google.com')
  end

  def test_extra_args
    get '/i', :url => 'http://google.com', 'out-format' => 'svg'
    assert last_response.ok?
    assert_equal 'CutyCapt', PinkyurlTest.args.shift
    assert PinkyurlTest.args.include?('--out-format=svg')
  end

  def test_args
    defaults = %w/ --out-format=png --delay=1000 --min-width=1024 /
    defaults.push "--user-styles=file://#{Pathname.new('public/stylesheets/cutycapt.css').realpath}"

    # valid ones
    assert_equal((defaults + %w/--out='foo;/).sort, args('out' => "'foo;").sort)

    # invalid ones
    assert_equal(defaults.sort, args('eofijout' => "'foo;").sort)
    assert_equal(defaults.sort, args('max-wait' => 0).sort)
    assert_equal(defaults.sort, args('user-styles' => 'file:///etc/passwd').sort)
  end
end
