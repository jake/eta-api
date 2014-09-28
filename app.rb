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
  after_update :push_estimate

  def url
    base = "https://maps.googleapis.com/maps/api/directions/json?alternatives=true&key=#{ENV['GOOGLE_API_KEY']}&departure_time=#{Time.now.to_i}"

    base.merge_query_params({ 'mode' => travel_mode, 'destination' => destination, 'origin' => origin })
  end

  def get_directions_json
    @directions_json = JSON.load(open(url))
  end

  def estimate
    get_directions_json

    estimates = []

    @directions_json['routes'].each do |route|
      seconds = 0

      route['legs'].each do |leg|
        seconds += leg['duration']['value'].to_i
      end

      estimates.push seconds
    end

    estimates.uniq!
    estimates.sort!

    first = (estimates.first.to_f / 60.0).round(3)
    last = (estimates.last.to_f / 60.0).round(3)

    unit = "minutes"

    if estimates.size == 0
      range = "Unknown..."
      unit = ""
    elsif estimates.size == 1
      range = "#{first}"
      unit = "minute" if first == 1
    else
      range = "#{first} to #{last}"
    end

    {
      values: estimates,
      range: range,
      unit: unit
    }
  end

  def push_estimate
    return unless changed?

    Pusher["#{token}_channel"].trigger('update_estimate', {
      directions: self.as_json,
      estimate: estimate
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

# CREATE
post '/directions' do
  directions = Directions.new

  directions.travel_mode = params[:travel_mode] unless params[:travel_mode].nil?
  directions.destination = params[:destination] unless params[:destination].nil?
  directions.origin = params[:origin] unless params[:origin].nil?

  directions.save

  directions.to_json
end

# SHOW
get '/directions/:token' do
  directions = Directions.find_by_token(params[:token])

  directions.as_json(methods: :estimate).to_json
end

# UPDATE
post '/directions/:token' do
  directions = Directions.find_by_token(params[:token])

  directions.travel_mode = params[:travel_mode] unless params[:travel_mode].nil?
  directions.destination = params[:destination] unless params[:destination].nil?
  directions.origin = params[:origin] unless params[:origin].nil?

  directions.save

  directions.to_json
end

# SHARE
get '/:token' do
  content_type :html

  @directions = Directions.find_by_token(params[:token])

  erb :share
end
