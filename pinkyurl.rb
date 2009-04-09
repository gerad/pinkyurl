require 'rubygems'
require 'sinatra'
require 'digest/sha1'
require 'image_science'

get '/' do
  'go to <a href="/crop/200/url/www.google.com">/crop/200/url/www.google.com</a>'
end

get %r{(/crop/(\d+))?/url/(.*)} do |x, crop, url|
  base = '/tmp/pinkyurl/' + Digest::SHA1.hexdigest(url)
  file =  base + '.png'

  unless File.exists?(file)
    options = "--user-agent='Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_6; en-us) AppleWebKit/530.5+ (KHTML, like Gecko) Version/4.0 Safari/528.16'"
    `xvfb-run --server-args="-screen 0, 1024x768x24" CutyCapt --url=http://#{url} --out=#{file} #{options}`
  end

  if crop
    ImageScience.with_image file do |img|
      w, h = img.width, img.height
      l, t, r, b = 0, 0, w, h

      t, b = 0, w if h > w

      img.with_crop l, t, r, b do |cropped|
        cropped.thumbnail crop do |thumb|
          file = base + "_#{crop}.png"
          thumb.save file
        end
      end
    end
  end

  send_file file
end
