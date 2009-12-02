require 'uri'
require 'cgi'
require 'set'
require 'digest/sha1'
require 'rubygems'
require 'sinatra'
require 'image_science'
require 'aws/s3'
require 'memcache'
require 'active_support'

#
# cache
#
class Cache
  @@bucket = 'pinkyurl.com'
  attr_reader :memcache

  def initialize
    config = YAML.load_file 'config/aws.yml'
    AWS::S3::Base.establish_connection! config

    config = YAML.load_file 'config/memcache.yml' rescue nil
    @memcache = MemCache.new config[:servers] || 'localhost:11211'
  end

  def expire file, host
    k = key file
    @memcache.delete k
    AWS::S3::S3Object.delete k, bucket(host)
  rescue Exception => e
    warn e
  end

  def put file, host, content_type = 'image/png'
    Thread.new { _put file, host, content_type }
  end

  def _put file, host, content_type = 'image/png'
    k = key file
    AWS::S3::Bucket.create bucket(host)
    AWS::S3::S3Object.store k, open(file), bucket(host),
      :content_type => content_type, :access => :public_read
    obj = AWS::S3::S3Object.find k, bucket(host)  # TODO: skip this extra find?
    returning 'https://s3.amazonaws.com' + obj.path do |r|
      @memcache.set k, r
    end
  end

  def get file, host
    k = key file
    r = @memcache.get k
    unless r
      obj = AWS::S3::S3Object.find k, bucket(host)
      @memcache.set k, r = 'https://s3.amazonaws.com' + obj.path
    end
    r
  rescue Exception => e
    warn e
    nil
  end

  def key file
    Digest::SHA1.hexdigest file
  end

  private
    def bucket host
      @@bucket + '-' + host
    end
end

class DisabledCache < Cache
  class DisabledMemCache
    def get k; end
    def set k, v; end
  end
  def initialize; @memcache = DisabledMemCache.new end
  def expire file, host; end
  def _put file, host, content_type = 'image/png'; file end
  def get file, host; end
end

configure do
  @@cache = DisabledCache.new
  @@allowable = Set.new %w/ url out out-format min-width max-wait delay /
end

configure :production do
  @@cache = Cache.new
end

#
# helpers
#
def args options = {}
  options.reverse_merge! 'out-format' => 'png', 'delay' => 1000
  options.select { |k, v| @@allowable.include? k }.map { |k, v| "--#{k}=#{v}" }
end

def cutycapt options = {}
  # Qt expects no %-escaping (http://doc.trolltech.com/4.5/qurl.html#QUrl)
  options['url'] = CGI.unescape options['url']
  if ENV['DISPLAY']
    system 'CutyCapt', *args(options)
  else
    system 'xvfb-run', '-a', '--server-args="-screen 0, 1024x768x24"', 'CutyCapt', *args(options)
  end
end

def cutycapt_with_cache options = {}, force=nil
  file = options['out']
  if force || !File.exists?(file)
    FileUtils.mkdir_p File.dirname(file)
    key = @@cache.key "cutycapt-#{file}"
    if !force && cached = @@cache.memcache.get(key)
      File.open file, 'w' do |f| f.write cached end
    else
      cutycapt options
      @@cache.memcache.set key, File.read(file) if File.size(file) < 1.megabyte
    end
  end
end

def crop input, output, size
  width, height = size.split 'x'
  ImageScience.with_image input do |img|
    w, h = img.width, img.height
    l, t, r, b = 0, 0, w, h

    if height
      b = (w.to_f / width.to_f * height.to_f).to_i
      b = h  if b > h
    else
      height = width.to_f / w * h
    end

    img.with_crop l, t, r, b do |cropped|
      cropped.resize width.to_i, height.to_i do |thumb|
        thumb.save output
      end
    end
  end
end

#
# routes/actions
#
get '/' do
  haml :index
end

get '/stylesheet.css' do
  content_type 'text/css'
  sass :stylesheet
end

get '/i' do
  url = params[:url]
  sha1_url = Digest::SHA1.hexdigest url
  host = (URI.parse(url).host rescue nil)
  halt 'invalid url'  unless host && host != 'localhost'

  crop = params[:crop]; crop = nil  if crop.nil? || crop == ''
  file = "public/cache/#{crop || 'uncropped'}/#{sha1_url}"

  if params[:expire]
    @@cache.expire file, host
  elsif cached = @@cache.get(file, host)
    halt redirect(cached)
  end

  uncropped = "public/cache/uncropped/#{sha1_url}"
  cutycapt_with_cache(params.merge('out' => uncropped), params[:expire])

  if crop && (!File.exists?(file) || params[:expire])
    FileUtils.mkdir_p File.dirname(file)
    crop uncropped, file, crop
  end

  content_type = Rack::Mime.mime_type('.' + (params['out-format'] || 'png'))
  @@cache.put file, host, content_type
  send_file file, :type => content_type
end

#
# views
#
__END__
@@stylesheet
# http://kuler.adobe.com/#themeID/162418
!green = #B5BF6B
!dark_green = #9FA668
!tan = #F2E0C9
!pink = #D98F89
!red = #8C2B2B
!highlight = !green + #333

=rounded(!width = 3px)
  :-webkit-border-radius = !width
  :-moz-border-radius = !width

body, input, button
  :font 32pt helvetica neue, helvetica, arial, sans-serif
  .minor, .minor input
    :font-size 12pt
body
  :background-color = !green + #111
  :background -webkit-gradient(radial, 50% 120, 40, 50% 200, 500, from(#{!green + #222}), to(#{!green})), -webkit-gradient(linear, 0% 0%, 0% 100%, from(#{!green}), to(#{!dark_green}))
  :text-shadow = !highlight 0px 1px 0px

a
  :color = !red
  :text-decoration none

input[type=submit]
  +rounded
  :padding-left 1ex
  :padding-right 1ex
  :border solid 1px gray
  :background -webkit-gradient(linear, 0% 0%, 0% 100%, from(white), to(#ddd))
  :text-shadow #fff 0px 1px 0px
  &:active
    :background -webkit-gradient(linear, 0% 100%, 0% 0%, from(#eee), to(#ddd))

input[type=text]
  :padding 0.4ex

form
  :text-align center
  :margin-top 2em
  input#url, input#file
    :width 20ex
  input#crop
    :width 5ex
  label
    :cursor pointer

@@ layout
%html
  %head
    %title= 'pinkyurl'
    %link{:rel => 'stylesheet', :type => 'text/css', :media => 'all', :href => '/stylesheet.css'}
    //%script{ :type => 'text/javascript', :src => 'http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js' }
    %script{ :type => 'text/javascript', :src => '/javascripts/jquery-1.3.2.js' }
  %body
    = yield
    %script{ :type => 'text/javascript', :src => 'http://static.getclicky.com/js' }
    %script{ :type => 'text/javascript' } clicky.init(157700);
    %noscript
      %img{ :width => 1, :height => 1, :src => 'http://static.getclicky.com/157700ns.gif' }

@@ index
%form{:action => '/i', :method => 'get'}
  %h1 snapshot any website
  %p
    %label{:for => 'url'} url
    %input{:name => 'url', :id => 'url', :type => 'text', :value => 'http://www.google.com'}
    %input{:type => 'submit', :value => 'create'}
    %a{:href => '#', :class => 'options'} options
  %p.minor{:style => 'display: none;'}
    %label{:for => 'crop'} crop
    %input{:name => 'crop', :id => 'crop'}
    %input{:name => 'expire', :id => 'expire', :type => 'checkbox', :value => 1}
    %label{:for => 'expire'} expire
:javascript
  $(document).ready(function() {
    $('form :input:visible:first').focus();
    $('a.options').click(function() {
      $('.minor').toggle('fast');
      return false;
    });
  });
