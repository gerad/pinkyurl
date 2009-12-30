module ImagesHelper
  def polaroids images
    images.map do |i|
      images_path(:url => i.url, :resize => 200)
    end
  end
end
