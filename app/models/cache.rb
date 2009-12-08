require 'memcache'

class Cache
  def self.create
    App['cache'] ? Cache.new : DisabledCache.new
  end

  @@bucket = 'pinkyurl.com'
  attr_reader :memcache

  def initialize
    config = YAML.load_file 'config/aws.yml'
    AWS::S3::Base.establish_connection! config
    AWS::S3::Bucket.create @@bucket

    config = YAML.load_file 'config/memcache.yml' rescue nil
    @memcache = MemCache.new config[:servers] || 'localhost:11211'
  end

  def expire file, host
    k = key file
    @memcache.delete k
    AWS::S3::S3Object.delete k, @@bucket
  rescue Exception => e
    warn e
  end

  def put file, host, content_type = 'image/png'
    Thread.new { _put file, host, content_type }
  end

  def _put file, host, content_type = 'image/png'
    k = key file
    AWS::S3::S3Object.store k, open(file), @@bucket,
      :content_type => content_type, :access => :public_read
    obj = AWS::S3::S3Object.find k, @@bucket  # TODO: skip this extra find?
    returning 'https://s3.amazonaws.com' + obj.path do |r|
      @memcache.set k, r
    end
  end

  def get file, host
    k = key file
    r = @memcache.get k
    unless r
      obj = AWS::S3::S3Object.find k, @@bucket
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
