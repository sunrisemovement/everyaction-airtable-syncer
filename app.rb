require 'httparty'
require 'dotenv'
require 'pry'
require 'sinatra'
require 'airrecord'

include Gem::Text

Dotenv.load

Airrecord.api_key = ENV['AIRTABLE_API_KEY']

USER = ENV.fetch('USERNAME', 'admin')
PASS = ENV.fetch('PASSWORD', 'admin')

use Rack::Auth::Basic, "Restricted Area" do |user, pass|
  user == USER && pass == PASS
end

class Hub < Airrecord::Table
  self.base_key = ENV['AIRTABLE_APP_KEY']
  self.table_name = 'Hubs'

  def should_appear_on_everyaction?
    return false unless self['Map?'] == true
    return false unless self['Latitude'] && self['Longitude']
    return false unless self['City'] && self['Name']
    true
  end
end

get '/' do
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


  airtable_hubs = Hub.all

  at_names_ea = airtable_hubs.
    select(&:should_appear_on_everyaction?).
    map { |h| h['Name'].sub(/^Sunrise\s/, '').strip }

  at_names_all = airtable_hubs.
    map { |h| h['Name'].sub(/^Sunrise\s/, '').strip }

  ea_set = Set.new(ea_names)
  at_set = Set.new(at_names_ea)
  at_all = Set.new(at_names_all)

  issues = []

  def closest(strings, s, suffix)
    matches = []
    distances = strings.map { |s2| levenshtein_distance(s, s2) }
    distances.each_with_index do |d, i|
      if d <= 2
        matches << strings[i]
      end
    end
    if matches.any?
      "<ul><li>Close #{suffix} matches: #{matches.map { |m| "<code>#{m}</code>" }.join(", ")}</li></ul>"
    end
  end

  (ea_set - at_all).each do |name|
    issues << "EveryAction contains <code>#{name}</code> but Airtable does not! #{closest(at_names_all, name, "AT")}"
  end

  (at_set - ea_set).each do |name|
    issues << "Airtable contains <code>#{name}</code> (as an active hub) but EveryAction does not! #{closest(ea_names, name, "EA")}"
  end

  unless ea_names.size == ea_set.size
    dupes = []
    counts = Hash.new { |h,k| h[k] = 0 }
    ea_names.each do |name|
      counts[name] += 1
      dupes << name if counts[name] > 1
    end
    dupes.each do |dupe|
      issues << "<code>#{dupe}</code> is listed in EA #{counts[dupe]} times!"
    end
  end

  if issues.length > 0
    <<-HTML
      <html>
        <head>
          <style>
            code {
              color: #d20600;
              padding: 1px 5px;
              background: #f8f8f8;
              border-radius: 5px;
              margin: 0 2px;
              white-space: nowrap;
            }
          </style>
        </head>
        <body>
          <h1>Airtable and EveryAction have some issues 😬</h1>
          <ol>
            #{issues.map{|i| %{<li>#{i}</li>} }.join("\n")}
          </ol>
        </body>
      </html>
    HTML
  else
    <<-HTML
      <html>
        <body>
          <h1>Airtable and EveryAction are </h1>
          <img src="/nsync.jpg" style="width: 100%">
        </body>
      </html>
    HTML
  end
end
