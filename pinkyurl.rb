require 'rubygems'
require 'sinatra'
require 'digest/sha1'

get '/' do
  'go to <a href="/url/www.google.com">/url/www.google.com</a>'
end

get %r{/url/(.*)} do |url|
  file = '/tmp/pinkyurl/' + Digest::SHA1.hexdigest(url) + '.png'

  unless File.exists?(file)
    `xvfb-run --server-args="-screen 0, 1024x768x24" CutyCapt --url=http://#{url} --out=#{file}`
  end

  send_file file
end
