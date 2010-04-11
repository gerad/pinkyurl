module Haml::Filters::Coffee
  include Haml::Filters::Base

  def render_with_options(text, options)
    js = IO.popen('coffee -sc', 'r+') do |c|
      c << text
      c.close_write
      c.read
    end
    <<END
<script type=#{options[:attr_wrapper]}text/javascript#{options[:attr_wrapper]}>
  //<![CDATA[
    #{js}
  //]]>
</script>
END
  end
end
