class IndexController < ApplicationController
  def index
    @merchant_id = GoogleCheckout[:merchant_id]
    @key =
      if cookies['key']
        Key.find_by_value(cookies['key'])
      elsif person
        person.keys.first
      end
    @images = Image.all :limit => 30
    @example = @images.rand.try(:url)
  end
end
