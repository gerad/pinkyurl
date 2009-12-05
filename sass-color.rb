require 'rubygems'
require 'sass'

#
# fix sass color math
#
class Sass::Script::Color
  def hsl
    rgb = @value.map { |c| c / 255.0 }
    min_rgb = rgb.min
    max_rgb = rgb.max
    delta = max_rgb - min_rgb

    lightness = (max_rgb + min_rgb) / 2.0

    if delta < 1e-5
      hue = 0
      saturation = 0
    else
      saturation = if ( lightness < 0.5 )
        delta / ( max_rgb + min_rgb )
      else
        delta / ( 2 - max_rgb - min_rgb )
      end

      deltas = rgb.map{|c| (((max_rgb - c) / 6.0) + (delta / 2.0)) / delta}

      hue = if (rgb[0] - max_rgb).abs < 1e-5
        deltas[2] - deltas[1]
      elsif (rgb[1] - max_rgb).abs < 1e-5
        ( 1.0 / 3.0 ) + deltas[0] - deltas[2]
      else
        ( 2.0 / 3.0 ) + deltas[1] - deltas[0]
      end
      hue += 1 if hue < 0
      hue -= 1 if hue > 1
    end

    [hue*360, saturation*100, lightness*100]
  end

  def self.from_hsl hsl
    Sass::Script::Functions::EvaluationContext.new(nil).hsl *hsl.map {|x| Sass::Script::Number.new(x) }
  end

  private
  def piecewise other, operation
    other_num = other.is_a? Sass::Script::Number
    if other_num && !other.unitless?
      raise Sass::SyntaxError.new("Cannot add a number with units (#{other}) to a color (#{self}).")
    end

    other_hsl = other.hsl
    if other_hsl[1] == 0
      result = (hsl = self.hsl).dup
      result[2] = (other_hsl[2] + hsl[2]) / 2.0
      Sass::Script::Color.from_hsl result
    else
      result = []
      for i in (0...3)
        res = rgb[i].send(operation, other_num ? other.value : other.rgb[i])
        result[i] = [ [res, 255].min, 0 ].max
      end
      with(:red => result[0], :green => result[1], :blue => result[2])
    end
  end
end
