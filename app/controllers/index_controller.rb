class IndexController < ApplicationController
  def index
    @example = 'http://' + %w/ google.com nytimes.com yahoo.com /.rand
    @merchant_id = GoogleCheckout[:merchant_id]
    @key = person.keys.first  if person
  end
end
