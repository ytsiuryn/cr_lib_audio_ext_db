require "spec"
require "../src/musicbrainz/release"

it "Musicbrainz#release" do
  r = parse_release(File.read("spec/data/musicbrainz/release.json"))

  r.title.should eq "The Dark Side of the Moon"
  r.roles["Pink Floyd"].should eq Set{"performer"}
  r.issues.actual.year.should eq 1973
  r.issues.actual.labels[0].name.should eq "Harvest"
  r.issues.actual.labels[0].ids[OnlineDB::MUSICBRAINZ].should eq "993af7f6-bb99-456b-83e7-5e728ea80a0e"
  r.issues.actual.catnos[0].should eq "SHVL 804"
  r.issues.actual.countries.should contain "GB"
  r.ids[ReleaseIdType::MUSICBRAINZ].should eq "b84ee12a-09ef-421b-82de-0441a926375b"
  r.ids[ReleaseIdType::MUSICBRAINZ_RELEASE_GROUP].should eq "f5093c06-23e3-404f-aeaa-40f72885ee3a"
  r.ids.should_not contain ReleaseIdType::BARCODE
  r.ids.should_not contain ReleaseIdType::ASIN
  r.issues.ancestor.year.should eq 1973
  r.type.should eq ReleaseType::ALBUM
  r.discs.size.should eq 1
  r.discs[0].fmt.media.should eq Media::LP
  r.discs[0].fmt.attrs.should contain "12\""
  r.tracks.size.should eq 10
  t = r.tracks[0]
  t.title.should eq "Speak to Me"
  t.disc_num.should eq 1
  t.ainfo.duration.should eq 68346
  t.ids[OnlineDB::MUSICBRAINZ].should eq "d4156411-b884-368f-a4cb-7c0101a557a2"
  t.genres.should contain "experimental"
  t.genres.should contain "progressive rock"
  t.genres.should contain "psychedelic rock"
  t.genres.should contain "rock"
  t.record.ids[RecordIdType::MUSICBRAINZ].should eq "bef3fddb-5aca-49f5-b2fd-d56a23268d63"
  t.record.roles["Peter James"].should eq Set{"engineer"}
  t.record.roles["Alan Parsons"].should eq Set{"engineer"}
  t.record.roles["Nick Mason"].should eq Set{"percussion", "tape"}
  t.record.roles["Roger Waters"].should eq Set{"tape"}
  t.record.roles["Richard Wright"].should eq Set{"piano"}
  t.record.roles["Chris Thomas"].should eq Set{"mix"}
  t.record.roles["Pink Floyd"].should eq Set{"producer"}
end
