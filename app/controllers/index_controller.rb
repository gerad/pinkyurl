class IndexController < ApplicationController
  def index
    @example = 'http://' + %w/ google.com nytimes.com yahoo.com /.rand
    @key = cookies['key']
  end

  def billing
    @merchant_id = GoogleCheckout[:merchant_id]
  end
end
