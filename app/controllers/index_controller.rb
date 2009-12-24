class IndexController < ApplicationController
  def index
    @example = 'http://' + %w/ google.com nytimes.com yahoo.com /.rand
    @merchant_id = GoogleCheckout[:merchant_id]
    @key =
      if cookies['key']
        Key.find_by_value(cookies['key'])
      elsif person
        person.keys.first
      end
  end
end
