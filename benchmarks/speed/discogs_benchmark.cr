require "benchmark"
require "../../src/discogs"

Benchmark.ips do |x|
  x.report("Discogs release JSON parsing") { parse_discogs_release(File.read("spec/data/discogs/release.json")) }
end
