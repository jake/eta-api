require 'dotenv'
Dotenv.load

require 'sinatra'
require 'json'

require 'sinatra/activerecord'

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

class Directions < ActiveRecord::Base
  @directions_json = {}

  before_create :generate_token
  after_update :push_estimates

  def url
    base = "https://maps.googleapis.com/maps/api/directions/json?alternatives=true&key=#{ENV['GOOGLE_API_KEY']}&departure_time=#{Time.now.to_i}"

    base.merge_query_params({ 'mode' => travel_mode, 'destination' => destination, 'origin' => origin })
  end

  def get_directions_json
    @directions_json = JSON.load(open(url))
  end

  def estimates
    get_directions_json

    estimates = []

    @directions_json['routes'].each do |route|
      seconds = 0

      route['legs'].each do |leg|
        seconds += leg['distance']['value']
      end

      estimates.push seconds
    end

    estimates.sort
  end

  def push_estimates
    return unless changed?

    Pusher["#{token}_channel"].trigger('update_estimates', {
      estimates: estimates
    })
  end

  protected

  def generate_token(length=10)
    self.token = loop do
      random_token = SecureRandom.hex(length)
      break random_token unless Directions.exists?(token: random_token)
    end
  end
end

before do
  content_type :json
end

post '/new' do
  directions = Directions.new

  directions.travel_mode = params[:travel_mode] unless params[:travel_mode].nil?
  directions.destination = params[:destination] unless params[:destination].nil?
  directions.origin = params[:origin] unless params[:origin].nil?

  directions.save

  directions.to_json
end

get '/directions/:token' do
  directions = Directions.find_by_token(params[:token])

  directions.to_json
end

post '/directions/:token' do
  directions = Directions.find_by_token(params[:token])

  directions.travel_mode = params[:travel_mode] unless params[:travel_mode].nil?
  directions.destination = params[:destination] unless params[:destination].nil?
  directions.origin = params[:origin] unless params[:origin].nil?

  directions.save

  directions.to_json
end
