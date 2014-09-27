require 'sinatra'
require 'json'

get '/' do
  content_type :json
  { hello: 'world' }.to_json
end