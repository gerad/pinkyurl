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
    FileUtils.rm_r File.dirname(__FILE__) + '/public', :force => true
  end

  def test_index
    get '/'
    assert last_response.ok?
    assert last_response.body[/form/]
  end

  def test_stylesheet
    get '/stylesheet.css'
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
    assert_equal %w( --delay=1000 --out-format=png --out=public/cache/uncropped/500b7ca9b58b5617d4f5565ce036335942707d07 --url=http://google.com ), PinkyurlTest.args.sort
  end

  def test_extra_args
    get '/i', :url => 'http://google.com', 'out-format' => 'svg'
    assert last_response.ok?
    assert_equal 'CutyCapt', PinkyurlTest.args.shift
    assert_equal %w( --delay=1000 --out-format=svg --out=public/cache/uncropped/c0707bd1efa93bfa02868cac022d98620a77cdb0 --url=http://google.com ), PinkyurlTest.args.sort
  end

  def test_args
    defaults = %w/ --out-format=png --delay=1000 /

    # valid ones
    assert_equal((defaults + %w/--out='foo;/).sort, args('out' => "'foo;").sort)

    # invalid ones
    assert_equal(defaults.sort, args('eofijout' => "'foo;").sort)
    assert_equal(defaults.sort, args('max-wait' => 0).sort)
    assert_equal(defaults.sort, args('user-styles' => 'file:///etc/passwd').sort)
  end
end
