module Haml::Filters::Coffee
  include Haml::Filters::Base

  lazy_require 'open3'

  def render_with_options(text, options)
    js, error = Open3.popen3('coffee', '-sc') do |i,o,e|
      i << text
      i.close
      [o.read, e.read]
    end
    raise SyntaxError, error unless error.blank?
    <<END
<script type=#{options[:attr_wrapper]}text/javascript#{options[:attr_wrapper]}>
  //<![CDATA[
    #{js}
  //]]>
</script>
END
  end
end
