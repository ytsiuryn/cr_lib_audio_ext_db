require "json"
require "core"
require "./common"

struct MusicbrainzInRelease
  include JSON::Serializable

  getter annotation : String?
  getter country : String?
  getter barcode : String?
  getter title : String
  getter id : String
  @[JSON::Field(key: "label-info")]
  getter label_info : Array(MusicbrainzLabelInfo)
  getter date : String
  getter media : Array(MusicbrainzInDisc)
  @[JSON::Field(key: "release-group")]
  getter release_group : MusicbrainzInReleaseGroup
  @[JSON::Field(key: "artist-credit")]
  getter artist_credit : Array(MusicbrainzArtistCredit)
  getter status : String
  getter asin : String?
end

struct MusicbrainzInDisc
  include JSON::Serializable

  getter position : Int32
  getter tracks : Array(MusicbrainzInTrack)
  @[JSON::Field(key: "track-count")]
  getter track_count : Int32
  getter format : String
end

struct MusicbrainzInTrack
  include JSON::Serializable

  getter title : String
  getter recording : MusicbrainzInRecord
  getter length : Int64?
  getter id : String
  getter number : String
end

struct MusicbrainzInRecord
  include JSON::Serializable

  getter id : String
  getter relations : Array(MusicbrainzRecordingRelation)
  getter genres : Array(MusicbrainzGenre)
end

struct MusicbrainzInReleaseGroup
  include JSON::Serializable

  getter id : String
  @[JSON::Field(key: "first-release-date")]
  getter first_release_date : String
  @[JSON::Field(key: "primary-type")]
  getter primary_type : String
end

def parse_musicbrainz_release(json : String) : Release
  r = Release.new
  in_r = MusicbrainzInRelease.from_json(json)

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
