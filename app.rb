require 'httparty'
require 'dotenv'
require 'pry'
require 'sinatra'

include Gem::Text

Dotenv.load

USER = ENV.fetch('USERNAME', 'admin')
PASS = ENV.fetch('PASSWORD', 'admin')

use Rack::Auth::Basic, "Restricted Area" do |user, pass|
  user == USER && pass == PASS
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

  airtable_hubs = JSON.parse(HTTParty.get("https://sunrise-hub-json.s3.amazonaws.com/hubs.json"))["map_data"]

  at_names = airtable_hubs.map { |h| h['name'].sub(/^Sunrise\s/, '').strip }

  ea_set = Set.new(ea_names)
  at_set = Set.new(at_names)

  issues = []

  def closest(strings, s, suffix)
    matches = []
    distances = strings.map { |s2| levenshtein_distance(s, s2) }
    distances.each_with_index do |d, i|
      if d <= 4
        matches << strings[i]
      end
    end
    if matches.any?
      "<ul><li>Close #{suffix} matches: #{matches.map { |m| "<code>#{m}</code>" }.join(", ")}</li></ul>"
    end
  end

  (ea_set - at_set).each do |name|
    issues << "<code>#{name}</code> is in EveryAction but not Airtable! #{closest(at_names, name, "AT")}"
  end

  (at_set - ea_set).each do |name|
    issues << "<code>#{name}</code> is in Airtable but not EveryAction! #{closest(ea_names, name, "EA")}"
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

  if issues.length
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
          <img src="https://pbs.twimg.com/profile_images/1240763924380815368/Z3SIqsSI_400x400.jpg">
        </body>
      </html>
    HTML
  end
end
