#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'

ENROLL_SECRET = 'L0UaFjL3MaP1R93'

db = SQLite3::Database.new 'biff.wellington.db'

class FleetManager < Sinatra::Base
  configure do
    set :bind, '0.0.0.0'
    set :environment, 'development'
  end

  before do
    content_type 'application/json'
  end

  post '/enroll' do
    puts "/enroll Body #{request.body.read}"
    {
      "node_key": 'some-node-key',
      "node_invalid": false
    }.to_json
  end

  post '/configuration' do
    puts "/configuration Body #{request.body.read}"
    File.read('config.json')
  end
end


