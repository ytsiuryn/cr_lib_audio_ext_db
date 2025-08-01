require "json"
require "core"
require "./common"

class ReleaseSearchItem
  include JSON::Serializable

  @[JSON::Field(ignore_serialize: true)]
  getter id : String
  @[JSON::Field(ignore_serialize: true)]
  getter title : String
  @[JSON::Field(ignore_serialize: true)]
  getter status : String
  @[JSON::Field(key: "artist-credir", ignore_serialize: true)]
  getter artist_credit : Array(ArtistCredit)
  # ReleaseGroup ShortReleaseGroup `json:"release-group"`
  @[JSON::Field(ignore_serialize: true)]
  getter barcode : String?
  @[JSON::Field(key: "label-info", ignore_serialize: true)]
  getter label_info : Array(LabelInfo)?
end

struct ReleaseSearchResult
  include JSON::Serializable

  @[JSON::Field(ignore_serialize: true)]
  getter releases : Array(ReleaseSearchItem)
end

def parse_search(json : String) : Array(Release)
  in_rs = ReleaseSearchResult.from_json(json)
  in_rs.releases.reduce(Array(Release).new(in_rs.releases.size)) { |ret, in_r| ret << release(in_r) }
end

private def release(in_r : ReleaseSearchItem) : Release
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
