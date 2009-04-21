require 'rubygems'
require 'sinatra'
require 'digest/sha1'
require 'image_science'

get '/' do
  'go to <a href="/crop/200/url/www.google.com">/crop/200/url/www.google.com</a>'
end

get %r{(/crop/(\d+))?/url/(.*)} do |x, crop, url|
  file = "public/url/#{url}"
  rurl = url + '?' + params.reject { |k, v| k == 'captures' }.map do |k, v|
    "#{k}=#{v}"
  end.join('&')

  FileUtils.mkdir_p File.dirname(file)
  `xvfb-run -a --server-args="-screen 0, 800x600x24" CutyCapt --delay=1000 --out-format=png --url=http://#{rurl} --out=#{file}`

  if crop
    ImageScience.with_image file do |img|
      w, h = img.width, img.height
      l, t, r, b = 0, 0, w, h

      t, b = 0, w if h > w

      img.with_crop l, t, r, b do |cropped|
        cropped.thumbnail crop do |thumb|
          file = "public/crop/#{crop}/url/#{url}"
          FileUtils.mkdir_p File.dirname(file)
          thumb.save file
        end
      end
    end
  end

  send_file file, :type => 'image/png'
end
