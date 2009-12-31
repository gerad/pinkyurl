require 'test_helper'

class ImagesHelperTest < ActionView::TestCase
  test "polaroids unescapes html" do
    assert_equal ["/i?resize=200&url=http%3A%2F%2Flocalhost%3A3000%2Fi%3Furl%3Dfoo"], polaroids(Image.all)
    assert_equal '["/i?resize=200&url=http%3A%2F%2Flocalhost%3A3000%2Fi%3Furl%3Dfoo"]', polaroids(Image.all).to_json
  end
end
