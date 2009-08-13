require 'uri'
require 'cgi'
require 'digest/sha1'
require 'rubygems'
require 'sinatra'
require 'image_science'
require 'aws/s3'
require 'memcache'

#
# cache
#
class Cache
  @@bucket = 'pinkyurl'
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

  def put file, host
    Thread.new do
      k = key file
      AWS::S3::Bucket.create bucket(host)
      AWS::S3::S3Object.store k, open(file), bucket(host),
        :content_type => 'image/png', :access => :public_read
      @memcache.set k, 'https://s3.amazonaws.com' + obj.path
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

  private
    def key file
      Digest::SHA1.hexdigest file
    end

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
  def put file, host; end
  def get file, host; end
end

configure do
  @@cache = DisabledCache.new
end

configure :production do
  @@cache = Cache.new
end

#
# helpers
#
def cutycapt url, file
  url = CGI.unescape url  # qt expects no %-escaping
                          # http://doc.trolltech.com/4.5/qurl.html#QUrl
  cmd = "CutyCapt --delay=1000 --out-format=png --url='#{url}' --out='#{file}'"
  if ENV['DISPLAY']
    `#{cmd}`
  else
    `xvfb-run -a --server-args="-screen 0, 800x600x24" #{cmd}`
  end
end

def cutycapt_with_cache url, file, force=nil
  if force || !File.exists?(file)
    FileUtils.mkdir_p File.dirname(file)
    if !force && cached = @@cache.memcache.get(file)
      File.open file, 'w' do |f| f.write cached end
    else
      cutycapt url, file
      @@cache.memcache.set file, File.read(file)
    end
  end
end

def crop input, output, size
  width, height = size.split 'x'
  ImageScience.with_image input do |img|
    w, h = img.width, img.height
    l, t, r, b = 0, 0, w, h

    if height
      b = w.to_f / width.to_f * height.to_f
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
  require 'haml'
  haml :index
end

get '/stylesheet.css' do
  require 'sass'
  sass :stylesheet
end

get '/i' do
  url = params[:url]
  host = (URI.parse(url).host rescue nil)
  halt 'invalid url'  unless host

  crop = params[:crop]; crop = nil  if crop.nil? || crop == ''
  file = "public/cache/#{crop || 'uncropped'}/#{CGI.escape url}"

  if params[:expire]
    @@cache.expire file, host
  elsif cached = @@cache.get(file, host)
    halt redirect(cached)
  end

  uncropped = "public/cache/uncropped/#{CGI.escape url}"
  cutycapt_with_cache url, uncropped, params[:expire]

  if crop && (!File.exists?(file) || params[:expire])
    FileUtils.mkdir_p File.dirname(file)
    crop uncropped, file, crop
  end

  @@cache.put file, host
  send_file file, :type => 'image/png'
end

#
# views
#
__END__
@@stylesheet
body, input
  :font-size 32pt
  .minor, .minor input
    :font-size 12pt
input[type=submit]
  :border solid 1px gray
  :-webkit-border-radius 5px
  :-moz-border-radius 5px

form
  :text-align center
  :margin-top 3em
  input#url
    :width 20ex
  input#crop
    :width 5ex

@@ index
%html
  %head
    %title= 'pinkyurl'
    %link{:rel => 'stylesheet', :type => 'text/css', :media => 'all', :href => '/stylesheet.css'}
  %body
    %form{:action => '/i', :method => 'get'}
      %p
        %label{:for => 'url'}= 'url'
        %input{:name => 'url', :id => 'url', :value => 'http://www.google.com'}
        %input{:type => 'submit', :value => 'Go'}
      %p.minor
        %label{:for => 'crop'}= 'crop'
        %input{:name => 'crop', :id => 'crop'}
        %input{:name => 'expire', :id => 'expire', :type => 'checkbox', :value => 1}
        %label{:for => 'expire'}= 'expire'
