require 'dotenv'
Dotenv.load

require 'sinatra'
require 'sinatra/redis'
require 'json'

require 'addressable/uri'
require 'open-uri'
require 'pusher'

Pusher.url = ENV['PUSHER_URL']

class String
  def merge_query_params(params={})
    uri = Addressable::URI.parse(self)
    uri.normalize!
    uri.query_values = (uri.query_values || {}).merge(params)
    uri.to_s
  end
end

class Directions
  @travel_mode = 'walking'
  @destination = nil
  @origin = nil

  @json = {}

  def travel_mode=(val)
    @travel_mode = val
  end

  def destination=(val)
    @destination = val
  end

  def origin=(val)
    @origin = val
  end

  def url
    base = "https://maps.googleapis.com/maps/api/directions/json?alternatives=true&key=#{ENV['GOOGLE_API_KEY']}&departure_time=#{Time.now.to_i}"

    base.merge_query_params({ 'mode' => @travel_mode, 'destination' => @destination, 'origin' => @origin })
  end

  def get_json
    @json = JSON.load(open(url))
  end

  def estimates
    get_json

    estimates = []

    @json['routes'].each do |route|
      seconds = 0

      route['legs'].each do |leg|
        seconds += leg['distance']['value']
      end

      estimates.push seconds
    end

    estimates.sort
  end
end

get '/estimates/:travel_mode/:origin/:destination' do
  content_type :json

  api = Directions.new

  api.travel_mode = params[:travel_mode]
  api.destination = params[:destination]
  api.origin = params[:origin]

  { estimates: api.estimates.to_json }.to_json
end
