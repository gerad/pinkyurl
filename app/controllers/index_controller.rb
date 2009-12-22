class IndexController < ApplicationController
  def index
    @example = 'http://' + %w/ google.com nytimes.com yahoo.com /.rand
    @merchant_id = GoogleCheckout[:merchant_id]
    #@key = cookies['key']
  end
end
