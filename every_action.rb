require 'httparty'
require 'dotenv'
require 'pry'

Dotenv.load

auth = {
  username: 'sunrise-movement',
  password: "#{ENV['EA_C3_KEY']}|1"
}

BASE_URL = "https://api.securevan.com/v4"
resp = HTTParty.post("#{BASE_URL}/echoes",
                     basic_auth: auth,
                     headers: {
                       "Content-Type" => "application/json"
                     },
                     body: { hello: 'world' }.to_json)
binding.pry

