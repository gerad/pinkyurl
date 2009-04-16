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
    `xvfb-run -a --server-args="-screen 0, 1024x768x24" CutyCapt --url=http://#{url} --out=#{file}`
  end

  if crop
    file = base + "_#{crop}.png"
    unless File.exists?(file)
      ImageScience.with_image file do |img|
        w, h = img.width, img.height
        l, t, r, b = 0, 0, w, h

        t, b = 0, w if h > w

        img.with_crop l, t, r, b do |cropped|
          cropped.thumbnail crop do |thumb|
            thumb.save file
          end
        end
      end
    end
  end

  send_file file
end
