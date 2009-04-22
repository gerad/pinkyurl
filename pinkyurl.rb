require 'open-uri'
require 'cgi'
require 'rubygems'
require 'sinatra'
require 'image_science'

get '/' do
  url = CGI.escape 'http://www.google.com'
  href = 'i?url=' + url + '&crop=200'
  "go to <a href=\"#{href}\">#{href}</a>"
end

get '/i' do
  url = params[:url]
  file = "public/cache/#{params[:crop]}/#{CGI.escape url}"

  unless File.exists?(file)
    FileUtils.mkdir_p File.dirname(file)
    `xvfb-run -a --server-args="-screen 0, 800x600x24" CutyCapt --delay=1000 --out-format=png --url=#{url} --out=#{file}`

    if params[:crop]
      ImageScience.with_image file do |img|
        w, h = img.width, img.height
        l, t, r, b = 0, 0, w, h

        t, b = 0, w if h > w

        img.with_crop l, t, r, b do |cropped|
          cropped.thumbnail params[:crop] do |thumb|
            thumb.save file
          end
        end
      end
    end
  end

  if params[:callback]
    Thread.new do
      open params[:callback]
    end
  end

  send_file file, :type => 'image/png'
end
