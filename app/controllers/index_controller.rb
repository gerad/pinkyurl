class IndexController < ApplicationController
  def index
    @example = 'http://' + %w/ google.com nytimes.com yahoo.com /.rand
  end
end
