module ImagesHelper
  def polaroids images
    images.map do |i|
      CGI.unescapeHTML images_path(:url => i.url, :resize => 200)
    end
  end
end
