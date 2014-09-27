require 'dotenv'
Dotenv.load

require 'sinatra'
require 'json'
require 'pusher'

Pusher.url = ENV['PUSHER_URL']

get '/' do
  content_type :json

  { hello: 'world' }.to_json
end