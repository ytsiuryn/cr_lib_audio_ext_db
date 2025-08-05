require "spec"
require "core"
require "../src/discogs/release"
require "../src/discogs/search"

it "#parse_release" do
  r, master_id = parse_discogs_release(File.read("spec/data/discogs/release.json"))

  master_id.should eq 10362

  r.title.should eq "The Dark Side Of The Moon"
  # r.roles["Pink Floyd"].should eq Set{"performer"}

  r.genres.should eq Set{"Rock", "Psychedelic Rock", "Prog Rock"}

  r.issues.actual.year.should eq 1977
  r.issues.actual.labels.size.should eq 1
  r.issues.actual.countries.should eq ["UK"]
  r.issues.actual.labels[0].name.should eq "Harvest"
  r.issues.actual.labels[0].catnos.should eq Set{"SHVL 804"}
  r.issues.actual.labels[0].ids[OnlineDB::DISCOGS].should eq "2564"

  r.roles["Chris Thomas"].should eq Set{"Mixed By [Supervised]"}
  r.roles["David Gilmour"].should eq Set{"Vocals", "Guitar", "Synthesizer [Vcs3]"}
  r.roles["EMI Records"].should eq Set{"Pressed By"}
  r.roles["Garrod & Lofthouse Ltd."].should eq Set{"Made By", "Printed By"}
  r.roles["George Hardie"].should eq Set{"Artwork [Sleeve Art, Stickers Art]"}
  r.roles["Harry Moss"].should eq Set{"Lacquer Cut By"}
  r.roles["Hipgnosis (2)"].should eq Set{"Design [Sleeve Design]", "Photography By"}
  r.roles["Nick Mason"].should eq Set{"Percussion", "Effects [Tape Effects]"}
  r.roles["Pink Floyd"].should eq Set{"Producer", "Music By"}
  r.roles["Pink Floyd Music Publishers"].should eq Set{"Published By"}
  r.roles["Roger Waters"].should eq Set{
    "Bass Guitar", "Vocals", "Synthesizer [Vcs3]", "Effects [Tape Effects]", "Lyrics By",
  }
  r.roles["The Gramophone Co. Ltd."].should eq Set{"Record Company", "Phonographic Copyright (p)"}

  r.total_discs.should eq 1
  r.discs[0].num.should eq 1
  r.discs[0].fmt.media.should eq Media::LP

  r.total_tracks.should eq 10
  r.tracks.size.should eq 10
  r.tracks[0].composition.roles["Nick Mason"].should eq Set{"Written-By"}
  r.tracks[1].composition.roles["David Gilmour"].should eq Set{"Written-By"}
  r.tracks[1].composition.roles["Roger Waters"].should eq Set{"Written-By"}
  r.tracks[1].composition.roles["Richard Wright"].should eq Set{"Written-By"}
  r.tracks[3].record.roles["Barry St. John"].should eq Set{"Backing Vocals"}
  r.tracks[3].record.roles["Doris Troy"].should eq Set{"Backing Vocals"}
  r.tracks[3].record.roles["Lesley Duncan"].should eq Set{"Backing Vocals"}
  r.tracks[3].record.roles["Liza Strike"].should eq Set{"Backing Vocals"}

  r.issues.actual.catnos.size.should eq 1
  r.ids[ReleaseIdType::DISCOGS].should eq "4139588"

  r.type.should eq ReleaseType::ALBUM
  r.repeat.should eq ReleaseRepeat::REPRESS

  r.pictures.size.should eq 0
  r.notes.size.should eq 1
end

it "#parse_search" do
  releases = parse_discogs_search(File.read("spec/data/discogs/search.json"))

  releases.size.should eq 24
end
