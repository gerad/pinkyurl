require 'uri'
require 'set'
require 'digest/sha1'
require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'image_science'
require 'active_support'

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
  @@cache = DisabledCache.new
  @@allowable = Set.new %w/ url out out-format min-width max-wait delay /
end

configure :production do
  require 'aws/s3'
  require 'memcache'
  @@cache = Cache.new
end

#
# helpers
#
def args options = {}
  options.reverse_merge! 'out-format' => 'png', 'delay' => 1000
  options.select { |k, v| @@allowable.include? k }.map { |k, v| "--#{k}=#{v}" }
end

def cutycapt options = {}
  # Qt expects no %-escaping (http://doc.trolltech.com/4.5/qurl.html#QUrl)
  options['url'] = Rack::Utils.unescape options['url']
  if ENV['DISPLAY']
    system 'CutyCapt', *args(options)
  else
    system 'xvfb-run', '-a', '--server-args="-screen 0, 1024x768x24"', 'CutyCapt', *args(options)
  end
end

def cutycapt_with_cache options = {}, force=nil
  file = options['out']
  if force || !File.exists?(file)
    FileUtils.mkdir_p File.dirname(file)
    key = @@cache.key "cutycapt-#{file}"
    if !force && cached = @@cache.memcache.get(key)
      File.open file, 'w' do |f| f.write cached end
    else
      cutycapt(options)  or raise "CutyCapt exit status #{$?.exitstatus}"
      @@cache.memcache.set key, File.read(file) if File.size(file) < 1.megabyte
    end
  end
end

def crop input, output, size
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
      cropped.resize width.to_i, height.to_i do |thumb|
        thumb.save output
      end
    end
  end
end

#
# routes/actions
#
get '/' do
  haml :index
end

get '/billing' do
  haml :billing
end

get '/stylesheet.css' do
  content_type 'text/css'
  sass :stylesheet
end

get '/i' do
  url = params[:url]
  sha1_url = Digest::SHA1.hexdigest(url + params.values_at(*@@allowable).compact.sort.to_s)
  host = (URI.parse(url).host rescue nil)
  halt 'invalid url'  unless host && host != 'localhost'

  crop = params[:crop]; crop = nil  if crop.nil? || crop == ''
  file = "public/cache/#{crop || 'uncropped'}/#{sha1_url}"

  if params[:expire]
    @@cache.expire file, host
  elsif cached = @@cache.get(file, host)
    halt redirect(cached)
  end

  uncropped = "public/cache/uncropped/#{sha1_url}"
  cutycapt_with_cache(params.merge('out' => uncropped), params[:expire])

  if crop && (!File.exists?(file) || params[:expire])
    FileUtils.mkdir_p File.dirname(file)
    crop uncropped, file, crop
  end

  content_type = Rack::Mime.mime_type('.' + (params['out-format'] || 'png'))
  @@cache.put file, host, content_type
  send_file file, :type => content_type
end

#
# views
#
__END__
@@stylesheet
// http://kuler.adobe.com/#themeID/660745
!black = #242424
!dark_green = #437346
!medium_green = #97D95C
!light_green = #D9FF77
!tan = #E9EB9B

// semantic names
!background = !medium_green
!dark_background = !dark_green
!highlight = !light_green
!link = !dark_green
!text = !black
!border = !black + #666

=rounded(!width = 3px)
  :-webkit-border-radius = !width
  :-moz-border-radius = !width
=drop_shadow
  :-webkit-box-shadow = 0px 2px 50px !dark_background
  :-moz-box-shadow = 0px 2px 50px !dark_background

body, input, button, select
  :font 32pt helvetica neue, helvetica, arial, sans-serif
  :color = !text
  .minor, .minor input, .minor select
    :font-size 18pt
body
  :text-align center
  :background-color = !background + #111
  :background -webkit-gradient(radial, 50% 120, 40, 50% 200, 500, from(#{!background + #222}), to(#{!background})), -webkit-gradient(linear, 0% 0%, 0% 100%, from(#{!background}), to(#{!dark_background}))
  :text-shadow = !highlight 0px 1px 0px

input[type=submit]
  +rounded
  :padding-left 1ex
  :padding-right 1ex
  :border = "solid" 1px !border
  :background -webkit-gradient(linear, 0% 0%, 0% 100%, from(white), to(#ddd))
  :text-shadow #fff 0px 1px 0px
  &:active
    :background -webkit-gradient(linear, 0% 100%, 0% 0%, from(#eee), to(#ddd))

input[type=text], select
  :padding 0.4ex

a
  :color = !link
  :text-decoration none

select
  :border = "solid" 1px !border

p
  :margin-top 0px

form
  :margin-top 1em
  input#url, input#file
    :width 20ex
  input#crop
    :width 5ex
  label
    :cursor pointer
    :margin-left 1ex

img.loading
  :margin-top 100px
img.thumbnail
  +drop_shadow

@@ layout
%html
  %head
    %title= 'pinkyurl'
    %link{:rel => 'stylesheet', :type => 'text/css', :media => 'all', :href => '/stylesheet.css'}
    //%script{ :type => 'text/javascript', :src => 'http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js' }
    %script{ :type => 'text/javascript', :src => '/javascripts/jquery-1.3.2.js' }
  %body
    = yield
    %script{ :type => 'text/javascript', :src => 'http://static.getclicky.com/js' }
    %script{ :type => 'text/javascript' } clicky.init(157700);
    %noscript
      %img{ :width => 1, :height => 1, :src => 'http://static.getclicky.com/157700ns.gif' }

@@ index
%form{:action => '/i', :method => 'get'}
  %h1 snapshot any website
  %p
    %label{:for => 'url'} url
    %input{:name => 'url', :id => 'url', :type => 'text', :value => 'http://www.google.com'}
    %input{:type => 'submit', :value => 'create'}
    %a{:href => '#', :class => 'options'} options
  %p.minor{:style => 'display: none;'}
    %label{:for => 'out-format'} format
    %select{:name => 'out-format', :id => 'out-format'}
      - %w/ png svg pdf jpg gif /.each do |f|
        %option= f
    %label{:for => 'crop'} crop
    %input{:name => 'crop', :id => 'crop', :value => 640}
    %label{:for => 'expire'} expire
    %input{:name => 'expire', :id => 'expire', :type => 'checkbox', :value => 1}
:javascript
  $(document).ready(function() {
    var loading = $('<img src="/images/loading.gif" />')
      .css('opacity', 0)
      .addClass('loading');
    $('a.options').click(function() {
      $('.minor').toggle('fast');
      return false;
    });
    $('form :input:visible:first').focus();
    $('form').submit(function() {
      var almostReady = false;
      var displayThumbnail = function() {
        if (!almostReady) {
          almostReady = true;
        } else {
          var f = $('form'),
              top = f.offset().top + f.outerHeight() + parseInt(f.css('marginBottom'));
          img
            .hide()
            .appendTo(document.body)
            .wrap($('<a>').attr('href', img.attr('src')))
            .css('position', 'absolute')
            .css('top', top)
            .css('left', ($(document).width() - img.width())/2)
            .fadeIn();
        }
      };
      var img = $('<img>')
        .addClass('thumbnail')
        .load(displayThumbnail)
        .attr('src', 'http://pinkyurl.com/i?' + $(this).serialize());
      $('h1')
        .fadeTo('normal', 0)
        .slideUp(function() {
          loading
            .appendTo(document.body)
            .fadeTo(1000, 1, displayThumbnail);
        });
      return false;
    });
  });

@@ billing
-# http://code.google.com/apis/checkout/developer/Google_Checkout_Beta_Subscriptions.html#HTML_Example
-MERCHANT_ID = 168965819365964
%form{:action => "https://checkout.google.com/api/checkout/v2/checkoutForm/Merchant/#{MERCHANT_ID}", :method => 'post'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.item-name', :value => 'PinkyURL Subscription'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.item-description', :value => '12 months of API access to PinkyURL'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.unit-price', :value => '0.00'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.unit-price.currency', :value => 'USD'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.quantity', :value => '1'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.type', :value => 'google'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.period', :value => 'MONTHLY'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.payments.subscription-payment-1.times', :value => '12'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.payments.subscription-payment-1.maximum-charge', :value => '12.00'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.payments.subscription-payment-1.maximum-charge.currency', :value => 'USD'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.item-name', :value => 'One month of API access to PinkyURL'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.item-description', :value => 'Flat charge for accessing PinkyURL'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.quantity', :value => '1'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.unit-price', :value => '12.00'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.unit-price.currency', :value => 'USD'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.digital-content.display-disposition', :value => 'OPTIMISTIC'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.digital-content.url', :value => 'http://pinkyurl.com'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.digital-content.url', :value => 'http://pinkyurl.com'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.subscription.recurrent-item.digital-content.description', :value => 'Continue back to PinkyURL'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.digital-content.display-disposition', :value => 'OPTIMISTIC'}
  %input{:type => 'hidden', :name => 'shopping-cart.items.item-1.digital-content.description', :value => 'Congratulations! Your subscription is being set up. Feel free to log onto &lt;a href="http:/pinkyurl.com"&gt;pinkyurl.com&lt;/a&gt;and try it out!'}
  %input{:type => 'hidden', :name => '_charset_'}
  %input{:type => 'image', :name => 'Google Checkout', :alt => 'Fast checkout through Google', :src => "http://checkout.google.com/buttons/checkout.gif?merchant_id=#{MERCHANT_ID}&w=180&h=46&style=white&variant=text&loc=en_US", :height => "46", :width => "180"}
