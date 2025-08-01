require "benchmark"
require "../../src/musicbrainz/search"
require "../../src/musicbrainz/release"

Benchmark.ips do |x|
  x.report("Raw JSON parsing") { File.open("spec/data/musicbrainz/release.json") { |f| ri = JSON.parse(f) } }
end
