require "json"
require "core"

struct DiscogsSearchResult
  include JSON::Serializable

  getter title : String
  getter label : Array(String)
  getter catno : String
  getter year : String?
  getter master_id : Int32
  getter id : Int32
end

# searchResponse is the search master list response.
struct DiscogsSearchResponse
  include JSON::Serializable

  getter results : Array(DiscogsSearchResult)
end

def parse_discogs_search(json : String) : Array(Release)
  sr = DiscogsSearchResponse.from_json(json)
  ret = Array.new(sr.results.size) { Release.new }

  sr.results.each_with_index do |result, i|
    next if result.master_id == 0

    ret[i].title = result.title
    ret[i].ids[ReleaseIdType::DISCOGS] = result.id.to_s

    if year = result.year.as(String).to_i?
      ret[i].issues.actual.year = year
    end

    result.label.each do |lbl|
      lb = Label.new(lbl)
      lb.catnos << result.catno
      ret[i].issues.actual.add_label(lb)
    end
  end

  ret.reject { |release| release.ids.size == 0 }
end
