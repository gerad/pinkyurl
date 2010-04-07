class GreenSavant
  def self.url
    @@url ||= URI.join GreenSavantConfig['url'], '/Log'
  end

  def self.enabled
    @@enabled ||= GreenSavantConfig['enabled']
  end

  def self.logger
    Rails.logger
  end

  def self.log data
    return unless enabled
    require 'net/http'
    Thread.new do
      begin
        logger.debug "GreenSavant logging #{url}"

        http = Net::HTTP.new url.host, url.port
        if URI::HTTPS === url
          require 'net/https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        res = nil
        seconds = Benchmark.realtime do
          http.start do
            req = Net::HTTP::Post.new url.request_uri
            req.body = data.to_json
            req.add_field 'Content-Type', 'application/json'
            res = http.request req
          end
        end

        logger.debug "GreenSavant logged #{url} #{res.code} #{res.message} (#{'%.1f' % seconds}s)"
      rescue Exception => e
        logger.fatal [e, e.backtrace].flatten.join "\n"
      end
    end
    
  end
end