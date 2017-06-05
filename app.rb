# frozon_string_literal: true
ENV['RACK_ENV'] ||= 'development'
require 'bundler'
Bundler.require 'default', ENV['RACK_ENV']
require 'tilt/erb'
MONGO = Mongo::Client.new(ENV.fetch('MONGODB_URI', 'mongodb://localhost:27017/covfefe'), heartbeat_frequency: 60 * 60)
MONGO[:apps].indexes.create_many(
  [
    { key: { name: 1 }, unique: true },
    { key: { name: 1, version: 1 }, unique: true },
  ]
)
MONGO[:hists].indexes.create_many(
  [
    { key: { app_id: 1, version: 1 }, unique: true },
  ]
)

class App < Sinatra::Base
  use Rack::Auth::Basic do |username, password|
    username == ENV['AUTH_USERNAME'] && password == ENV['AUTH_PASSWORD']
  end if ENV.key? 'AUTH_USERNAME' and ENV.key? 'AUTH_PASSWORD'

  enable :method_override

  helpers do
    def apps_find_or_create(name)
      name = name.to_s

      app = MONGO[:apps].find(name: name).limit(1).first
      [
        app || { _id: BSON::ObjectId.new, name: name, version: 0, data: [] },
        app.nil?
      ]
    end
  end

  get '/:name' do
    name = params[:name]
    app, = apps_find_or_create name

    content_type :json
    app[:data].sort_by { |key, _| key }.to_h.to_json
  end

  post '/:name/set' do
    name = params[:name]
    app, is_new = apps_find_or_create name

    payload = begin
                JSON.parse request.body.read
              ensure
                request.body.rewind
              end
    payload ||= {}
    payload = payload
                .map { |key, val| [key.to_s, val.to_s] }
                .reject { |key, _| key.empty? }
                .to_h

    if payload.size.positive?

      old = app.dup

      app[:version] += 1
      app[:data] = app[:data].to_h.merge(payload).to_a

      MONGO[:hists].insert_one(
        _id:     BSON::ObjectId.new,
        app_id:  old[:_id],
        version: old[:version],
        data:    old[:data]
      )

      if is_new
        MONGO[:apps].insert_one(app)
      else
        MONGO[:apps].update_one({ _id: app[:_id], version: old[:version] }, app)
      end

    end

    content_type :json
    app[:data].to_h.to_json
  end

  post '/:name/unset' do
    name = params[:name]
    app, is_new = apps_find_or_create name

    payload = begin
                JSON.parse request.body.read
              ensure
                request.body.rewind
              end
    keys = payload&.keys&.map(&:to_s) || []

    if keys.size.positive?

      old = app.dup

      app[:version] += 1
      app[:data] = app[:data].reject { |key, _| keys.include? key.to_s }

      MONGO[:hists].insert_one(
        _id:     BSON::ObjectId.new,
        app_id:  old[:_id],
        version: old[:version],
        data:    old[:data]
      )

      if is_new
        MONGO[:apps].insert_one(app)
      else
        MONGO[:apps].update_one({ _id: app[:_id], version: old[:version] }, app)
      end
    end

    content_type :json
    app[:data].to_h.to_json
  end
end
