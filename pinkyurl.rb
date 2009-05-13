require 'uri'
require 'cgi'
require 'digest/sha1'
require 'rubygems'
require 'sinatra'
require 'image_science'
require 'aws/s3'
require 'memcache'

class Cache
  @@bucket = 'pinkyurl'

  def initialize
    config = YAML.load_file 'config/aws.yml'
    AWS::S3::Base.establish_connection! config

    config = YAML.load_file 'config/memcache.yml' rescue nil
    @memcache = MemCache.new config[:servers] || 'localhost:11211'
  end

  def expire file, host
    @memcache.delete file
    AWS::S3::S3Object.delete key(file), bucket(host)
  rescue Exception => e
    warn e
  end

  def put file, host
    Thread.new do
      AWS::S3::Bucket.create bucket(host)
      AWS::S3::S3Object.store key(file), open(file), bucket(host),
        :content_type => 'image/png', :access => :public_read
      @memcache.set file, 'https://s3.amazonaws.com' + obj.path
    end
  end

  def get file, host
    r = @memcache.get file
    unless r
      obj = AWS::S3::S3Object.find key(file), bucket(host)
      @memcache.set file, r = 'https://s3.amazonaws.com' + obj.path
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
  def expire file, host; end
  def put file, host; end
  def get file, host; end
end

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

def crop file, size
  width, height = size.split 'x'
  ImageScience.with_image file do |img|
    w, h = img.width, img.height
    l, t, r, b = 0, 0, w, h

    if height
      b = w.to_f / width.to_f * height.to_f
    else
      height = width.to_f / w * h
    end

    img.with_crop l, t, r, b do |cropped|
      cropped.resize width.to_i, height.to_i do |thumb|
        thumb.save file
      end
    end
  end
end

configure do
  @@cache = DisabledCache.new
end

configure :production do
  @@cache = Cache.new
end

get '/' do
  url = CGI.escape 'http://www.google.com'
  href = 'i?url=' + url + '&crop=200'
  "go to <a href=\"#{href}\">#{href}</a>"
end

get '/i' do
  url = params[:url]
  host = (URI.parse(url).host rescue nil)
  halt 'no url'  unless host

  file = "public/cache/#{params[:crop] || 'uncropped'}/#{CGI.escape url}"

  if params[:expire]
    @@cache.expire file, host
  elsif cached = @@cache.get(file, host)
    halt redirect(cached)
  end

  if !File.exists?(file) || params[:expire]
    FileUtils.mkdir_p File.dirname(file)
    cutycapt url, file
    crop file, params[:crop]  if params[:crop]
  end

  @@cache.put file, host
  send_file file, :type => 'image/png'
end
