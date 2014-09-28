ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'

require_relative 'app.rb'
 
include Rack::Test::Methods
 
def app
  Sinatra::Application
end

describe "ETA API" do
  it "should return json" do
    get '/'
    last_response.headers['Content-Type'].must_equal 'application/json'
  end
end