require 'uri'
require 'set'
require 'digest/sha1'
require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'image_science'
require 'active_support'
require 'lib/sass-color'

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
  set :allowable, Set.new(%w/ url out out-format min-width delay /)
  set :cache, DisabledCache.new
end

configure :production do
  require 'aws/s3'
  require 'memcache'
  set :cache, Cache.new
end

#
# helpers
#
module CutyCapt
  def args opt = {}
    user_styles = File.dirname(__FILE__) + '/public/stylesheets/cutycapt.css'
    opt.reverse_merge! 'out-format' => 'png', 'delay' => 1000, 'min-width' => 1024
    opt.
      select { |k, v| options.allowable.include? k }.
      map { |k, v| "--#{k}=#{v}" } +
      [ "--user-styles=file://#{Pathname.new(user_styles).realpath}",
        "--max-wait=5000" ]
  end

  def cutycapt opt = {}
    # Qt expects no %-escaping (http://doc.trolltech.com/4.5/qurl.html#QUrl)
    opt['url'] = Rack::Utils.unescape opt['url']
    if ENV['DISPLAY']
      system 'CutyCapt', *args(opt)
    else
      system 'xvfb-run', '-a', '--server-args="-screen 0, 1024x768x24"', 'CutyCapt', *args(opt)
    end
  end

  def cutycapt_with_cache opt = {}, force=nil
    file = opt['out']
    if force || !File.exists?(file)
      FileUtils.mkdir_p File.dirname(file)
      key = options.cache.key "cutycapt-#{file}"
      if !force && cached = options.cache.memcache.get(key)
        File.open file, 'w' do |f| f.write cached end
      else
        cutycapt(opt)  or raise "CutyCapt exit status #{$?.exitstatus}"
        options.cache.memcache.set key, File.read(file) if File.size(file) < 1.megabyte
      end
    end
  end

  def resize input, output, size
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
        cropped.resize width.to_i, height.to_i do |resized|
          resized.save output
        end
      end
    end
  end

  def crop input, output, rblt
    r, b, l, t = *rblt.split(/\D+/).compact
    ImageScience.with_image input do |img|
      img.with_crop l.to_i, t.to_i, r.to_i, b.to_i do |cropped|
        cropped.save output
      end
    end
  end
end
helpers CutyCapt

#
# routes/actions
#
get '/' do
  @example = 'http://' + %w/ google.com nytimes.com yahoo.com /.rand
  haml :index
end

get '/billing' do
  haml :billing
end

get '/stylesheets/application.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet, :style => :compressed
end

get '/i' do
  url = params[:url]
  sha1_url = Digest::SHA1.hexdigest(url + params.values_at(*options.allowable).hash.to_s)
  host = (URI.parse(url).host rescue nil)
  halt 'invalid url'  unless host && host != 'localhost'

  resize = params[:resize]; resize = nil  if resize.blank?
  crop = params[:crop]; crop = nil  if crop.blank?
  file = "public/cache/#{resize || 'full'}-#{crop || 'uncropped'}/#{sha1_url}"

  if params[:expire]
    options.cache.expire file, host
  elsif cached = options.cache.get(file, host)
    halt redirect(cached)
  end

  full = "public/cache/full-uncropped/#{sha1_url}"
  cutycapt_with_cache(params.merge('out' => full), params[:expire])

  if (resize || crop) && (!File.exists?(file) || params[:expire])
    FileUtils.mkdir_p File.dirname(file)
    resize full, file, resize  if resize
    crop resize ? file : full, file, crop  if crop
  end

  content_type = Rack::Mime.mime_type('.' + (params['out-format'] || 'png'))
  options.cache.put file, host, content_type
  send_file file, :type => content_type
end

get '/error' do
  raise 'testing hoptoad'
end
