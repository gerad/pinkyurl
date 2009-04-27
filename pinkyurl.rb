require 'cgi'
require 'digest/sha1'
require 'rubygems'
require 'sinatra'
require 'image_science'
require 'aws/s3'
require 'memcache'

class Cache
  def initialize
    config = YAML.load_file 'config/aws.yml'
    AWS::S3::Base.establish_connection! config
    AWS::S3::Bucket.create 'pinkyurl'

    config = YAML.load_file 'config/memcache.yml' rescue nil
    @memcache = MemCache.new config[:servers] || 'localhost:11211'
  end

  def put file
    Thread.new do
      key = Digest::SHA1.hexdigest file
      AWS::S3::S3Object.store key, open(file), 'pinkyurl',
        :content_type => 'image/png', :access => :public_read
      @memcache.set file, 'https://s3.amazonaws.com' + obj.path
    end
  end

  def get file
    r = @memcache.get file
    unless r
      key = Digest::SHA1.hexdigest file
      obj = AWS::S3::S3Object.find key, 'pinkyurl'
      @memcache.set file, r = 'https://s3.amazonaws.com' + obj.path
    end
    r
  rescue Exception => e
    warn e
    nil
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

  if cached = @@cache.get(file)
    halt redirect(cached)
  end

  unless File.exists?(file)
    FileUtils.mkdir_p File.dirname(file)
    cutycapt url, file
    crop file, params[:crop] if params[:crop]
  end

  @@cache.put file
  send_file file, :type => 'image/png'
end
