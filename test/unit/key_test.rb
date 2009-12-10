require 'test_helper'

class KeyTest < ActiveSupport::TestCase
  test "keys are case sensitive" do
    k = Key.create
    bad = k.value.downcase
    assert_not_equal bad, k.value
    assert_nil Key.from_param(bad)
  end
end
