require "json"
require "core"

struct MasterInfo
  include JSON::Serializable

  getter year : Int32
end

struct InRelease
  include JSON::Serializable

  getter id : Int32
  getter year : Int32
  getter artists : Array(Artist)
  getter labels : Array(Company)
  getter companies : Array(Company)
  getter formats : Array(Format)
  getter master_id : Int32?
  getter title : String
  getter country : String
  getter notes : String
  # _identifiers: serde_json::Value, // Vec<Identifier> TODO: альтенативные catno/label - использовать для определения схожести?
  getter genres : Array(String)
  getter styles : Array(String)
  getter tracklist : Array(Tracklist)
  getter extraartists : Array(Artist)
  getter images : Array(Image)
end

class Artist
  include JSON::Serializable

  getter name : String
  getter role : String
  getter tracks : String
  getter id : Int32
end

class Company
  include JSON::Serializable

  getter name : String
  getter catno : String
  @[JSON::Field(key: "entity-type-name", ignore_serialize: true)]
  getter entity_type_name : String
  getter id : Int32
end

class Format
  include JSON::Serializable

  getter name : String
  getter descriptions : Array(String)
end

class Image
  include JSON::Serializable

  getter type : String
  getter uri : String
end

class Tracklist
  include JSON::Serializable

  getter position : String
  getter title : String
  getter duration : String
  getter extraartists : Array(Artist)?
end

def master(io : IO, r : Release) : Nil
  mi = JSON.parse(io)
  r.issues.ancestor.year = mi["year"].as_i
  r.issues.ancestor.notes << mi["notes"].as_s
end

# Разбор ответа по релизу и дополнительная отправка Master ID.
def parse_release(io : IO) : {Release, Int32}
  ri = JSON.parse(io)
  r = Release.new
  r.ids[ReleaseIdType::DISCOGS] = ri["id"].as_i.to_s
  r.title = ri["title"].as_s
  r.notes << ri["notes"].as_s
  ri["genres"].as_a.each { |g| r.genres << g.as_s }
  ri["styles"].as_a.each { |g| r.genres << g.as_s }
  companies(ri, r)
  publishing(ri, r)
  tracks(ri, r)
  extra_actors(ri["extraartists"], r)
  release_props(ri, r)
  pictures(ri, r)
  {r, ri.as_h.has_key?("master_id") ? ri["master_id"].as_i : 0}
end

private def publishing(ri : JSON::Any, r : Release) : Nil
  p = r.issues.actual
  p.year = ri["year"].as_i
  p.countries << ri["country"].as_s
  ri["labels"].as_a.each do |lbl|
    name = lbl["name"].as_s
    unless p.label(name)
      lb = Label.new(name)
      lb.catnos << lbl["catno"].as_s
      lb.ids[OnlineDB::DISCOGS] = lbl["id"].as_i.to_s
      p.add_label(lb)
    end
  end
end

# Компании являются акторами.
private def companies(ri : JSON::Any, r : Release) : Nil
  ri["companies"].as_a.each do |c|
    name = c["name"].as_s
    r.add_actor(name, OnlineDB::DISCOGS, c["id"].as_i.to_s)
    r.add_role(name, c["entity_type_name"].as_s)
  end
end

# Формирование списка треков и задействованных артистов в них
private def tracks(ri : JSON::Any, r : Release) : Nil
  ri["tracklist"].as_a.each_with_index do |tr, i|
    t = Track.new(pos: tr["position"].as_s, index: i)
    t.title = tr["title"].as_s
    duration = tr["duration"].as_s
    unless duration.empty?
      t.ainfo = AudioInfo.new(duration: duration.to_i)
    end
    if tr.as_h.includes?("extraartists")
      extra_actors(tr["extraartists"], r)
    end
    r.tracks << t
  end
  r.total_tracks = ri["tracklist"].size
end

private def extra_actors(actors : JSON::Any, r : Release) : Nil
  actors.as_a.each do |a|
    name = a["name"].as_s
    role = a["role"].as_s
    id = a["id"].as_i.to_s
    if a["tracks"].as_s.empty?
      r.add_actor(name, OnlineDB::DISCOGS, id)
      r.add_role(name, role)
    else
      positions = r.tracks.to_range(a["tracks"].as_s, delimiter: " to ")
      positions.each do |pos|
        t = r.tracks.track(pos)
        if t
          track_actors_by_role(t, role).add(name, role)
          r.add_actor(name, OnlineDB::DISCOGS, id)
        end
      end
    end
  end
end

private def track_actors_by_role(t : Track, role : String) : Roles
  if {"Composer", "Lyricist", "Written-By"}.includes?(role)
    return t.composition.roles
  end
  t.record.roles
end

private def release_props(ri : JSON::Any, r : Release) : Nil
  ri["formats"].as_a.each_with_index do |fmt, i|
    d = Disc.new(i + 1)
    d.fmt.media = Media.new(fmt["name"].as_s)
    fmt["descriptions"].as_a.each do |jprop|
      prop = jprop.as_s
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
          d.fmt.media = val
        end
        if d.fmt.media == Media::UNKNOWN
          d.fmt.attrs << prop
        end
      end
    end
    r.discs << d
    r.total_discs = ri["formats"].as_a.size
  end
end

# Берем только обложки, потому что другие типы изображения четко не определены.
def pictures(ri : JSON::Any, r : Release) : Nil
  ri["images"].as_a.each do |img|
    if img["uri"]? && img["image_type"]?
      img_type = (
        img["image_type"].as_s == "primary" ? PictType::COVER_FRONT : PictType::OTHER_ICON
      )
      p = PictureInAudio.new(img_type)
      p.url = img["uri"].as_s
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
# 			for artist in tr['ExtraArtists']:
# 				artist.TrackActor(r, t)
# 				t.Record.Roles.Add(artist.Name, artist.Role)
# 			for artist in st['ExtraArtists']:
# 				artist.TrackActor(r, t)
# 				t.Record.Roles.Add(artist.Name, artist.Role)
# 	else:
# 		t.SetPosition(tr.Position)
# 		t.SetTitle(tr.Title)
# 		t.Duration = intutils.NewDurationFromString(tr.Duration)
# 		for artist in tr['ExtraArtists'];
# 			artist.TrackActor(r, t)
# 			t.Record.Roles.Add(artist.Name, artist.Role)
# 	return t
