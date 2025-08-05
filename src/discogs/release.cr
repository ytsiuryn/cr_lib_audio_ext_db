require "json"
require "core"

class DiscogsMasterInfo
  include JSON::Serializable

  getter year : Int32
  getter notes : String
end

class InDiscogsRelease
  include JSON::Serializable

  getter id : Int32
  getter year : Int32
  getter artists : Array(DiscogsArtist)
  getter labels : Array(DiscogsCompany)
  getter companies : Array(DiscogsCompany)
  getter formats : Array(DiscogsFormat)
  getter master_id : Int32?
  getter title : String
  getter country : String
  getter notes : String
  # _identifiers: serde_json::Value, // Vec<Identifier> TODO: альтенативные catno/label - использовать для определения схожести?
  getter genres : Array(String)
  getter styles : Array(String)
  getter tracklist : Array(DiscogsTracklist)
  getter extraartists : Array(DiscogsArtist)
  getter images : Array(DiscogsImage)
end

class DiscogsArtist
  include JSON::Serializable

  getter name : String
  getter role : String
  getter tracks : String
  getter id : Int32
end

struct DiscogsCompany
  include JSON::Serializable

  getter name : String
  getter catno : String
  getter entity_type_name : String
  getter id : Int32
end

struct DiscogsFormat
  include JSON::Serializable

  getter name : String
  getter descriptions : Array(String)
end

struct DiscogsImage
  include JSON::Serializable

  getter type : String
  getter uri : String
end

class DiscogsTracklist
  include JSON::Serializable

  getter position : String
  getter title : String
  getter duration : String
  getter extraartists : Array(DiscogsArtist)?
end

def master(json : String, r : Release) : Nil
  mi = DiscogsMasterInfo.from_json(json)
  r.issues.ancestor.year = mi.year
  r.issues.ancestor.notes << mi.notes
end

# Разбор ответа по релизу и дополнительная отправка Master ID.
def parse_discogs_release(json : String) : {Release, Int32}
  in_r = InDiscogsRelease.from_json(json)
  r = Release.new
  r.ids[ReleaseIdType::DISCOGS] = in_r.id.to_s
  r.title = in_r.title
  r.notes << in_r.notes
  in_r.genres.each { |genre| r.genres << genre }
  in_r.styles.each { |genre| r.genres << genre }
  companies(in_r, r)
  publishing(in_r, r)
  tracks(in_r, r)
  extra_actors(in_r.extraartists, r)
  release_props(in_r, r)
  pictures(in_r, r)
  {r, in_r.master_id ? in_r.master_id.as(Int32) : 0}
end

private def publishing(in_r : InDiscogsRelease, r : Release) : Nil
  p = r.issues.actual
  p.year = in_r.year
  p.countries << in_r.country
  in_r.labels.each do |lbl|
    unless p.label(lbl.name)
      lb = Label.new(lbl.name)
      lb.catnos << lbl.catno
      lb.ids[OnlineDB::DISCOGS] = lbl.id.to_s
      p.add_label(lb)
    end
  end
end

# Компании являются акторами.
private def companies(in_r : InDiscogsRelease, r : Release) : Nil
  in_r.companies.each do |company|
    r.add_actor(company.name, OnlineDB::DISCOGS, company.id.to_s)
    r.add_role(company.name, company.entity_type_name)
  end
end

# Формирование списка треков и задействованных артистов в них
private def tracks(in_r : InDiscogsRelease, r : Release) : Nil
  tracks = Array.new(in_r.tracklist.size) { Track.new }
  in_r.tracklist.each_with_index do |track, i|
    tracks[i].position = track.position
    tracks[i].index = i
    tracks[i].title = track.title
    duration = track.duration
    unless duration.empty?
      tracks[i].ainfo = AudioInfo.new(duration: duration.to_i)
    end
    if track.extraartists
      extra_actors(track.extraartists.as(Array(DiscogsArtist)), r)
    end
  end
  r.tracks = Tracks.new(tracks)
  r.total_tracks = in_r.tracklist.size
end

private def extra_actors(actors : Array(DiscogsArtist), r : Release) : Nil
  actors.each do |actor|
    id = actor.id.to_s
    if actor.tracks.empty?
      r.add_actor(actor.name, OnlineDB::DISCOGS, id)
      actor.role.split(/,(?![^\[]*\])/).map(&.strip).each do |role|
        track_actors_by_role(r, nil, role).add(actor.name, role)
      end
    else
      positions = r.tracks.to_range(actor.tracks, delimiter: " to ")
      positions.each do |pos|
        t = r.tracks.track(pos)
        if t
          actor.role.split(/,(?![^\[]*\])/).map(&.strip).each do |role|
            track_actors_by_role(r, t, role).add(actor.name, role)
            r.add_actor(actor.name, OnlineDB::DISCOGS, id)
          end
        end
      end
    end
  end
end

private def track_actors_by_role(r : Release, t : Track | Nil, role : String) : Roles
  if {"Producer", "Pressed By", "Made By", "Printed By", "Published By"}.includes?(role)
    r.roles
  elsif t && {"Music By", "Composer", "Lyricist", "Written-By"}.includes?(role)
    t.composition.roles
  elsif role.starts_with?("Artwork") || role.starts_with?("Design") || role.starts_with?("Lacquer")
    r.roles
  elsif t
    t.record.roles
  else
    r.roles
  end
end

private def release_props(in_r : InDiscogsRelease, r : Release) : Nil
  discs = Array.new(in_r.formats.size) { Disc.new }
  in_r.formats.each_with_index do |fmt, i|
    discs[i].num = i + 1
    discs[i].fmt.media = Media.new(fmt.name)
    fmt.descriptions.each do |prop|
      if val = ReleaseStatus.parse?(prop)
        r.status = val
      elsif val = ReleaseRepeat.parse?(prop)
        r.repeat = val
      elsif val = ReleaseRemake.parse?(prop)
        r.remake = val
      elsif val = ReleaseOrigin.parse?(prop)
        r.origin = val
      elsif val = ReleaseType.parse?(prop)
        r.type = val
      else
        if val = Media.parse?(prop)
          discs[i].fmt.media = val
        end
        if discs[i].fmt.media == Media::UNKNOWN
          discs[i].fmt.attrs << prop
        end
      end
    end
    r.discs = Discs.new(discs)
    r.total_discs = in_r.formats.size
  end
end

# Берем только обложки, потому что другие типы изображения четко не определены.
def pictures(in_r : InDiscogsRelease, r : Release) : Nil
  in_r.images.each do |img|
    unless img.type.empty? || img.uri.empty?
      img_type = (
        img.type == "primary" ? PictType::COVER_FRONT : PictType::OTHER_ICON
      )
      p = PictureInAudio.new(img_type)
      p.url = img.uri
      r.pictures << p
    end
  end
end

# def Track(r: Release) -> Track:
# 	t = Track()
# 	if tr['SubTracks']:
# 		for st in tr['SubTracks']:
# 			if tr.Position:
# 				t.SetPosition(md.ComplexPosition(tr.Position, st.Position))
# 			else:
# 				t.SetPosition(st.Position)
# 			t.SetTitle(md.ComplexTitle(tr.Title, st.Title))
# 			t.Duration = intutils.NewDurationFromString(st.Duration)
# 			for artist in tr['ExtraDiscogsArtists']:
# 				artist.TrackActor(r, t)
# 				t.Record.Roles.Add(artist.Name, artist.Role)
# 			for artist in st['ExtraDiscogsArtists']:
# 				artist.TrackActor(r, t)
# 				t.Record.Roles.Add(artist.Name, artist.Role)
# 	else:
# 		t.SetPosition(tr.Position)
# 		t.SetTitle(tr.Title)
# 		t.Duration = intutils.NewDurationFromString(tr.Duration)
# 		for artist in tr['ExtraDiscogsArtists'];
# 			artist.TrackActor(r, t)
# 			t.Record.Roles.Add(artist.Name, artist.Role)
# 	return t
