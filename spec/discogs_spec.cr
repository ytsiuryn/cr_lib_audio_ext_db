require "spec"
require "core"
require "../src/discogs/release"

it "#parse_release" do
  r, master_id = File.open("spec/data/discogs/release.json", mode: "rb") { |file| parse_release(file) }
  master_id.should eq 10362
  r.title.should eq "The Dark Side Of The Moon"
  # r.roles["Pink Floyd"].should eq Set{"performer"}
  r.issues.actual.year.should eq 1977
  r.issues.actual.labels.size.should eq 1
  # r.issues.actual.catnos.size.should eq 2
  r.issues.actual.countries.should contain "UK"
  r.ids[ReleaseIdType::DISCOGS].should eq "4139588"
  r.discs.size.should eq 1
  r.discs[0].fmt.media.should eq Media::LP
  r.type.should eq ReleaseType::ALBUM
  r.repeat.should eq ReleaseRepeat::REPRESS
  r.genres.size.should eq 3
  r.tracks.size.should eq 10
end
