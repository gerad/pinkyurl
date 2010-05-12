class IndexController < ApplicationController
  def index
    @key = get_key
    @images = Image.all :limit => 15, :order => 'created_at DESC'
    @example = @images.rand.try(:url)
  end

  def pricing
    @merchant_id = GoogleCheckout[:merchant_id]
    @key = get_key
  end

  private
  def get_key
    if cookies['key']
      Key.find_by_value(cookies['key'])
    elsif person
      person.keys.first
    end
  end

end
