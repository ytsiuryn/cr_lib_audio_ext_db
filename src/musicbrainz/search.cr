require "json"
require "core"
require "./common"

class MusicbrainzReleaseSearchItem
  include JSON::Serializable

  getter id : String
  getter title : String
  getter status : String
  @[JSON::Field(key: "artist-credir")]
  getter artist_credit : Array(MusicbrainzArtistCredit)
  # ReleaseGroup ShortReleaseGroup `json:"release-group"`
  getter barcode : String?
  @[JSON::Field(key: "label-info")]
  getter label_info : Array(MusicbrainzLabelInfo)?
end

struct MusicbrainzReleaseSearchResult
  include JSON::Serializable

  getter releases : Array(MusicbrainzReleaseSearchItem)
end

def parse_musicbrainz_search(json : String) : Array(Release)
  in_rs = MusicbrainzReleaseSearchResult.from_json(json)
  in_rs.releases.reduce(Array(Release).new(in_rs.releases.size)) { |ret, in_r| ret << release(in_r) }
end

private def release(in_r : MusicbrainzReleaseSearchItem) : Release
  r = Release.new

  r.ids[ReleaseIdType::MUSICBRAINZ] = in_r.id
  r.title = in_r.title
  if barcode = in_r.barcode
    r.ids[ReleaseIdType::BARCODE] = barcode
  end
  if in_si = in_r.label_info
    in_si.label_info.each { |in_label| label_info(in_label, r) }
  end
  r.status = ReleaseStatus.new(in_r.status)

  in_r.artist_credit.each { |in_actor| add_performer(in_actor, r) }

  r
end

# FIXME: [musicbrainz] Атрымана Search(<release>)
# Error: "missing field `label-info` at line 1 column 1812"
