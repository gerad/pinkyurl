require 'sass-color'
require 'test/unit'
require 'ruby-debug'

class SassColorTest < Test::Unit::TestCase
  def setup
    @green = Sass::Script::Color.new [0, 255, 0]
  end

  def test_hsl
    assert_equal [120, 100, 50], @green.hsl.map(&:to_i)
    green2 = Sass::Script::Color.from_hsl @green.hsl
    assert_equal [0, 255, 0], green2.rgb
  end

  def test_plus_white
    @white = Sass::Script::Color.new [255, 255, 255]
    assert_equal [0, 0, 100], @white.hsl
    @light_green = @green.plus(@white)
    assert_equal [120, 100, 75], @light_green.hsl.map(&:to_i)
    assert_equal '#80ff80', @light_green.to_s
  end
end
