class ImagesController < ApplicationController
  before_filter :check_key
  around_filter :log_stats
  after_filter :track_polaroids

  @@allowable = Set.new(%w/ url out out-format min-width delay /)

  def create
    params[:url] = 'http://' + params[:url]  unless params[:url] =~ %r'://'
    url = @stats[:url] = params[:url]
    host = (URI.parse(url).host rescue nil)
    unless host && host != 'localhost'
      render :text => 'invalid url', :status => :unprocessable_entity
      return
    end

    sha1_url = Digest::SHA1.hexdigest(url + params.values_at(*@@allowable).hash.to_s)
    resize = params[:resize]; resize = nil  if resize.blank?
    crop = params[:crop]; crop = nil  if crop.blank?
    file = Rails.root + "tmp/cache/#{resize || 'full'}-#{crop || 'uncropped'}/#{sha1_url}"

    if params[:expire]
      cache.expire file, host
    elsif cached = cache.get(file, host)
      @stats[:cache_hit] = true
      redirect_to cached
      return
    end

    full = Rails.root + "tmp/cache/full-uncropped/#{sha1_url}"
    cutycapt_with_cache(params.merge('out' => full), params[:expire])

    if (resize || crop) && (!File.exists?(file) || params[:expire])
      FileUtils.mkdir_p File.dirname(file)
      resize full, file, resize  if resize
      crop resize ? file : full, file, crop  if crop
    end

    content_type = Rack::Mime.mime_type('.' + (params['out-format'] || 'png'))
    cache.put file, host, content_type
    send_file file, :type => content_type, :disposition => 'inline'
  end
  alias_method :index, :create

  private
    def check_key
      @key = Key.find_by_value(params[:key])
      unless self_referential? || @key
        raise SecurityError, "invalid key"
      end
    end

    def cache; @@cache ||= Cache.create end

    def args opt = {}
      user_styles = Rails.root + 'public/stylesheets/cutycapt.css'
      opt.reverse_merge! 'out-format' => 'png', 'delay' => 1000, 'min-width' => 1024
      opt.
        select { |k, v| @@allowable.include? k }.
        map { |k, v| "--#{k}=#{v}" } +
        [ "--user-styles=file://#{user_styles.realpath}",
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
        key = cache.key "cutycapt-#{file}"
        if !force && cached = cache.memcache.get(key)
          File.open file, 'w' do |f| f.write cached end
        else
          cutycapt(opt)  or raise "CutyCapt exit status #{$?.exitstatus}"
          cache.memcache.set key, File.read(file) if File.size(file) < 1.megabyte
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

    def log_stats
      @stats = {
        :access_at => Time.now,
        :referrer => request.referrer,
        :api_key => @key.try(:secret) }
      begin
        @stats[:seconds] = Benchmark.realtime do
          yield
        end
      ensure
        GreenSavant.log @stats if @key and not self_referential?
      end
    end

    def track_polaroids
      if (200 .. 299).include?(response.status.to_i) && self_referential?
        url = params[:url]
        digest = Digest::SHA1.hexdigest url
        Image.create :url => url, :digest => digest unless Image.find_by_digest(digest)
      end
    end

    def self_referential?
      same_host? request.url, request.headers['Referer']
    end

    def same_host? a, b
      URI.parse(a).host == URI.parse(b).host rescue false
    end
end
