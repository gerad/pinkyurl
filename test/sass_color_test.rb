require 'sass-color'
require 'test/unit'
require 'ruby-debug'

class SassColorTest < Test::Unit::TestCase
  def setup
    @green = Sass::Script::Color.new [0, 255, 0]
    @white = Sass::Script::Color.new [255, 255, 255]
  end

  def test_hsl
    assert_equal [120, 100, 50], @green.hsl.map(&:to_i)
    assert_equal [0, 0, 100], @white.hsl
  end

  def test_from_hsl
    green_rgb = Sass::Script::Color.from_hsl @green.hsl
    assert_equal [0, 255, 0], green_rgb.rgb
  end

  def test_plus_white
    @light_green = @green.plus(@white)
    assert_equal [120, 100, 75], @light_green.hsl.map(&:to_i)
    assert_equal '#80ff80', @light_green.to_s

    @light_green = @white.plus(@green)
    assert_equal [120, 100, 75], @light_green.hsl.map(&:to_i)
    assert_equal '#80ff80', @light_green.to_s
  end

  def test_minus_white
    @dark_green = @green.minus(@white)
    assert_equal [120, 100, 25], @dark_green.hsl.map(&:to_i)
    assert_equal 'green', @dark_green.to_s
  end

  def test_other_is_num
    @gray = @white.minus(Sass::Script::Number.new(2))
    assert_equal '#fdfdfd', @gray.to_s
  end
end
