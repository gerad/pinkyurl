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
    AWS::S3::Bucket.create @@bucket

    config = YAML.load_file 'config/memcache.yml' rescue nil
    @memcache = MemCache.new config[:servers] || 'localhost:11211'
  end

  def expire file
    @memcache.delete file
    AWS::S3::S3Object.delete key(file), @@bucket
  rescue Exception => e
    warn e
  end

  def put file
    Thread.new do
      AWS::S3::S3Object.store key(file), open(file), @@bucket,
        :content_type => 'image/png', :access => :public_read
      @memcache.set file, 'https://s3.amazonaws.com' + obj.path
    end
  end

  def get file
    r = @memcache.get file
    unless r
      obj = AWS::S3::S3Object.find key(file), @@bucket
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
end

def cutycapt url, file
  url = CGI.unescape url  # qt expects no %-escaping
                          # http://doc.trolltech.com/4.5/qurl.html#QUrl
  cmd = "CutyCapt --delay=1000 --out-format=png --url=#{url} --out=#{file}"
  if ENV['DISPLAY']
    `#{cmd}`
  else
    `xvfb-run -a --server-args="-screen 0, 800x600x24" #{cmd}`
  end
end

def crop file, size
  ImageScience.with_image file do |img|
    w, h = img.width, img.height
    l, t, r, b = 0, 0, w, h

    t, b = 0, w if h > w

    img.with_crop l, t, r, b do |cropped|
      cropped.thumbnail size do |thumb|
        thumb.save file
      end
    end
  end
end

configure do
  @@cache = Cache.new
end

get '/' do
  url = CGI.escape 'http://www.google.com'
  href = 'i?url=' + url + '&crop=200'
  "go to <a href=\"#{href}\">#{href}</a>"
end

get '/i' do
  url = params[:url]
  file = "public/cache/#{params[:crop]}/#{CGI.escape url}"

  if params[:expire]
    @@cache.expire file
  elsif cached = @@cache.get(file)
    halt redirect(cached)
  end

  if !File.exists?(file) || params[:expire]
    FileUtils.mkdir_p File.dirname(file)
    cutycapt url, file
    crop file, params[:crop]  if params[:crop]
  end

  @@cache.put file
  send_file file, :type => 'image/png'
end
