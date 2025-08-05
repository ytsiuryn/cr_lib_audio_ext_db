require "benchmark"
require "../../src/musicbrainz"

Benchmark.ips do |x|
  x.report("Musicbrainz release JSON parsing") { 
    parse_musicbrainz_release(File.read("spec/data/musicbrainz/release.json")) 
  }
end
