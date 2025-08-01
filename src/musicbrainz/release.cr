require "json"
require "core"
require "./common"

struct InRelease
  include JSON::Serializable

  @[JSON::Field(ignore_serialize: true)]
  getter annotation : String?
  @[JSON::Field(ignore_serialize: true)]
  getter country : String?
  @[JSON::Field(ignore_serialize: true)]
  getter barcode : String?
  @[JSON::Field(ignore_serialize: true)]
  getter title : String
  @[JSON::Field(ignore_serialize: true)]
  getter id : String
  @[JSON::Field(key: "label-info", ignore_serialize: true)]
  getter label_info : Array(LabelInfo)
  @[JSON::Field(ignore_serialize: true)]
  getter date : String
  @[JSON::Field(ignore_serialize: true)]
  getter media : Array(InDisc)
  @[JSON::Field(key: "release-group", ignore_serialize: true)]
  getter release_group : InReleaseGroup
  @[JSON::Field(key: "artist-credit", ignore_serialize: true)]
  getter artist_credit : Array(ArtistCredit)
  @[JSON::Field(ignore_serialize: true)]
  getter status : String
  @[JSON::Field(ignore_serialize: true)]
  getter asin : String?
end

struct InDisc
  include JSON::Serializable

  @[JSON::Field(ignore_serialize: true)]
  getter position : Int32
  @[JSON::Field(ignore_serialize: true)]
  getter tracks : Array(InTrack)
  @[JSON::Field(key: "track-count", ignore_serialize: true)]
  getter track_count : Int32
  @[JSON::Field(ignore_serialize: true)]
  getter format : String
end

struct InTrack
  include JSON::Serializable

  @[JSON::Field(ignore_serialize: true)]
  getter title : String
  @[JSON::Field(ignore_serialize: true)]
  getter recording : InRecord
  @[JSON::Field(ignore_serialize: true)]
  getter length : Int64?
  @[JSON::Field(ignore_serialize: true)]
  getter id : String
  @[JSON::Field(ignore_serialize: true)]
  getter number : String
end

struct InRecord
  include JSON::Serializable

  @[JSON::Field(ignore_serialize: true)]
  getter id : String
  @[JSON::Field(ignore_serialize: true)]
  getter relations : Array(RecordingRelation)
  @[JSON::Field(ignore_serialize: true)]
  getter genres : Array(Genre)
end

struct InReleaseGroup
  include JSON::Serializable

  @[JSON::Field(ignore_serialize: true)]
  getter id : String
  @[JSON::Field(key: "first-release-date", ignore_serialize: true)]
  getter first_release_date : String
  @[JSON::Field(key: "primary-type", ignore_serialize: true)]
  getter primary_type : String
end

def parse_release(json : String) : Release
  r = Release.new
  in_r = InRelease.from_json(json)

  r.title = in_r.title

  if in_r.country
    r.issues.actual.countries << in_r.country.as(String)
  end

  begin
    r.issues.actual.year = Int32.new(in_r.date)
  rescue
    r.issues.actual.year = Time::Format::ISO_8601_DATE.parse(in_r.date).year
  end

  r.ids[ReleaseIdType::MUSICBRAINZ] = in_r.id
  r.status = ReleaseStatus.parse(in_r.status)

  if in_r.barcode
    r.ids[ReleaseIdType::BARCODE] = in_r.barcode.as(String)
  end
  if in_r.asin
    r.ids[ReleaseIdType::ASIN] = in_r.asin.as(String)
  end

  if in_r.release_group
    r.ids[ReleaseIdType::MUSICBRAINZ_RELEASE_GROUP] = in_r.release_group.id
    r.issues.ancestor.year = Time::Format::ISO_8601_DATE.parse(
      in_r.release_group.first_release_date.as(String)).year
    r.type = ReleaseType.parse(in_r.release_group.primary_type)
  end

  unless in_r.media.empty?
    total_tracks = 0
    i = 0
    in_r.media.each do |disc|
      total_tracks += disc.track_count
      d = Disc.new(disc.position)
      disc.format.split(" ").each do |lexem|
        m = Media.new(lexem)
        if m == Media::UNKNOWN
          d.fmt.attrs << lexem
        else
          d.fmt.media = m
        end
      end
      r.discs << d
      disc.tracks.each do |in_tr|
        # t = track(in_tr, i, r)
        t = Track.new(in_tr.number, index: i)
        t.title = in_tr.title
        if length = in_tr.length
          t.ainfo = AudioInfo.new(duration: length)
        end
        t.ids[OnlineDB::MUSICBRAINZ] = in_tr.id
        in_tr.recording.genres.each { |in_genre| t.genres << in_genre.name }
        t.record.ids[RecordIdType::MUSICBRAINZ] = in_tr.recording.id
        in_tr.recording.relations.each { |rel| add_actor(rel, r, t) }

        t.disc_num = disc.position
        r.tracks << t # TODO: подсчитать общее кол-во треков и задать размер массива
        i += 1
      end
    end
    r.total_tracks = total_tracks
    r.total_discs = in_r.media.size
  end

  in_r.label_info.each { |in_lbl| label_info(in_lbl, r) }
  in_r.artist_credit.each { |in_artist| add_performer(in_artist, r) }

  r
end
