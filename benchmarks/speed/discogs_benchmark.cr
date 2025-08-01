require "benchmark"
require "../../src/discogs/release"

Benchmark.ips do |x|
  x.report("Search JSON parsing") do
    File.open("spec/data/discogs/release.json", mode: "rb") { |file| parse_release(file) }
  end
end
