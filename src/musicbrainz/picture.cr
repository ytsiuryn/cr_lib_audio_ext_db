require "json"
require "core"

class Thumbnail
  include JSON::Serializable

  getter large : String
end

class ImageInfo
  include JSON::Serializable

  getter thumbnails : Thumbnail
  getter comment : String
  getter types : Array(String)
end

struct CoverInfo
  include JSON::Serializable

  getter images : Array(ImageInfo)
end

def parse_picture(json : String) : PictureInAudio | Nil
  in_p = CoverInfo.from_json(json)
  in_p.images.each do |in_img|
    in_img.types.each do |img_type|
      if img_type == "Front"
        ret = PictureInAudio(PictType::COVERFRONT)
        ret.url = in_img.thumbnails.large
        if comment = in_img.comment
          ret.notes << comment
        end
        return ret
      end
    end
  end
end
