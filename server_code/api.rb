#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'base64'

ENROLL_SECRET = 'somesecret' # Reminder that this must match db.secret

class FleetManager < Sinatra::Base
  configure do
    set :bind, '0.0.0.0'
    set :environment, 'development'
  end

  before do
    content_type 'application/json'
  end

  post '/enroll' do
    body = parse_body_json
    puts "configuration: #{body}"

    node_invalid = true
    if ENROLL_SECRET == body['enroll_secret']
      node_invalid = false
      node_key = Enrollment.create(
        platform_type: body['platform_type'],
        host_identifier: body['host_identifier'],
        host_details: body['host_details']
      ).node_key
    end
    {
      node_key: node_key,
      node_invalid: node_invalid
    }.to_json
  end

  post '/configuration' do
    body = parse_body_json
    puts "configuration: #{body}"
    enrolled = Enrollment.find(node_key: body['node_key'])

    return enrolled.query.to_json if enrolled

    {
      schedule: {},
      node_invalid: true # if invalid it will make the osclient re-enroll
    }.to_json
  end

  private

  def parse_body_json
    JSON.parse(request.body.read)
  rescue StandardError => e
    puts e.message
    {} # return empty hash if the json from the client is invalid and we can't parse
  end
end

Enrollment = Struct.new(:id, :host_identifier, :platform_type, :host_details, :node_key) do
  TABLE_NAME = 'enrollment'

  # Find Enrollment using an ID or node_key
  def self.find(id: nil, node_key: nil)
    if id
      column = 'id'
      value = id
    elsif node_key
      column = 'node_key'
      value = node_key
    end
    raise 'ID or node_key are required' if value.nil?

    record = DB.execute("SELECT * FROM #{TABLE_NAME} WHERE #{column} = ? LIMIT 1", value).first
    return if record.nil?

    Enrollment.new(*record)
  end

  # Encoding ENROLL_SECRET and Time into a string makes
  # it harder for the client to guess someone else enrollment.
  # Makes it so they can't just increase or decrease the ID and
  # find the next users enrollment. More can be added to make guessing
  # the key harder, but for now, this is a scalable solution.
  def self.create_node_key
    Base64.urlsafe_encode64("#{ENROLL_SECRET}-#{Time.now.to_i}")
  end

  # Just to help out with debugging the DB
  # Never used in the code. but nice to have
  def self.all
    DB.execute(
      "SELECT id, host_identifier, platform_type, host_details, node_key FROM #{TABLE_NAME}"
    ).map { |v| Enrollment.new(*v) }
  end

  # Create a new Enrollment in the database with a node_key attached
  def self.create(platform_type:, host_identifier:, host_details:)
    node_key = create_node_key
    sql_query = <<-SQL
      INSERT INTO #{TABLE_NAME} (platform_type, host_identifier, host_details, node_key)
      VALUES (?, ?, ?, ?)
    SQL
    DB.execute(
      sql_query,
      platform_type.to_i,
      host_identifier,
      host_details.to_json,
      node_key
    )
    id = DB.execute('SELECT last_insert_rowid()').flatten.first
    Enrollment.new(id, host_identifier, platform_type.to_i, host_details.to_json, node_key)
  end

  # Just to help out with testing
  def host_details_serialized
    JSON.parse(host_details)
  end

  def query
    {
      schedule: {
        select_processes: {
          interval: '5',
          description: "select all running processes",
          query: "SELECT * FROM processes;"
        }
      },
      "node_invalid": false
    }
  end
end
