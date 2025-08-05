require "json"
require "core"

class MusicbrainzThumbnail
  include JSON::Serializable

  getter large : String
end

class MusicbrainzImageInfo
  include JSON::Serializable

  getter thumbnails : MusicbrainzThumbnail
  getter comment : String
  getter types : Array(String)
end

struct MusicbrainzCoverInfo
  include JSON::Serializable

  getter images : Array(MusicbrainzImageInfo)
end

def parse_musicbrainz_picture(json : String) : PictureInAudio | Nil
  in_p = MusicbrainzCoverInfo.from_json(json)
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
