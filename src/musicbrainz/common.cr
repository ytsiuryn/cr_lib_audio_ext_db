require "json"
require "core"

struct MusicbrainzGenre
  include JSON::Serializable

  getter name : String
end

class MusicbrainzArtist
  include JSON::Serializable

  getter id : String
  getter disambiguation : String
  getter name : String
end

class MusicbrainzArtistCredit
  include JSON::Serializable

  getter artist : MusicbrainzArtist
end

class MusicbrainzLabelInfo
  include JSON::Serializable

  @[JSON::Field(key: "catalog-number")]
  getter catalog_number : String?
  getter label : MusicbrainzArtist
end

class MusicbrainzRecordingRelation
  include JSON::Serializable

  getter attributes : Array(String)
  getter type : String
  getter artist : MusicbrainzArtist
end

def add_performer(ac : MusicbrainzArtistCredit, r : Release) : Nil
  if actor = ac.artist.name
    r.actors[actor] = IDs.new
    r.actors[actor][OnlineDB::MUSICBRAINZ] = ac.artist.id
    r.add_role(actor, "performer")
  end
end

def label_info(in_lbl : MusicbrainzLabelInfo, r : Release) : Nil
  ll = r.issues.actual.label(in_lbl.label.name)
  lb = ll || Label.new(in_lbl.label.name)
  lb.ids[OnlineDB::MUSICBRAINZ] = in_lbl.label.id
  if in_lbl.catalog_number
    lb.catnos << in_lbl.catalog_number.as(String)
  end
  r.issues.actual.add_label(lb)
end

def add_actor(actor : MusicbrainzRecordingRelation, r : Release, t : Track) : Nil
  name = actor.artist.name
  return if name.empty?
  roles = Array(String).new
  if actor.type == "instrument"
    roles.concat(actor.attributes)
  else
    roles << actor.type
  end
  roles.each do |role|
    role_location(r, t, role).add(name, role)
    r.add_actor(name, OnlineDB::MUSICBRAINZ, actor.artist.id)
  end
end

# Определяет коллекцию для размещения описания по наименованию роли.
# Это может быть коллекция для описания акторов произведения, записи или релиза.
def role_location(r : Release, t : Track, role : String) : Roles
  case role
  when "design", "illustration", "design/illustration", "photography"
    r.roles
  when "composer", "lyricist", "writer"
    t.composition.roles
  else
    t.record.roles
  end
end
