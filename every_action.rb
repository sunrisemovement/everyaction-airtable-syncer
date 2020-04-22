require 'httparty'
require 'dotenv'
require 'pry'

include Gem::Text

Dotenv.load

custom_fields = HTTParty.get(
  "https://api.securevan.com/v4/customFields",
  basic_auth: {
    username: "sunrise-movement",
    password: "#{ENV['EA_C3_KEY']}|1"
  },
  headers: { "Content-Type" => "application/json" }
)

hub_field = custom_fields.detect { |f| f['customFieldName'] == "Hub Affiliation" }

ea_names = hub_field['availableValues'].map{ |v| v['name'].strip }

airtable_hubs = JSON.parse(HTTParty.get("https://sunrise-hub-json.s3.amazonaws.com/hubs.json"))["map_data"]

at_names = airtable_hubs.map { |h| h['name'].sub(/^Sunrise\s/, '').strip }

ea_set = Set.new(ea_names)
at_set = Set.new(at_names)

issues = []

def closest(strings, s)
  distances = strings.map { |s2| levenshtein_distance(s, s2) }
  strings[distances.index(distances.min)]
end

(ea_set - at_set).each do |name|
  issues << "#{name} is in EveryAction but not Airtable! Closest AT match is \"#{closest(at_names, name)}\""
end

(at_set - ea_set).each do |name|
  issues << "#{name} is in Airtable but not EveryAction! Closest EA match is \"#{closest(ea_names, name)}\""
end

unless ea_names.size == ea_set.size
  dupes = []
  counts = Hash.new { |h,k| h[k] = 0 }
  ea_names.each do |name|
    counts[name] += 1
    dupes << name if counts[name] > 1
  end
  dupes.each do |dupe|
    issues << "#{dupe} is listed in EA #{counts[dupe]} times!"
  end
end

binding.pry

