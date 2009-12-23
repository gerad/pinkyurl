require 'test_helper'

class KeyTest < ActiveSupport::TestCase
  test "keys are case insensitive" do
    k = Key.create
    bad = k.secret.downcase
    assert_not_equal bad, k.secret
    assert_equal k, Key.from_param(bad)
  end
end
