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
    if valid_enroll_key?(body['enroll_secret'])
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

    return File.read('config.json') if enrolled

    {
      schedule: {},
      node_invalid: true # if invalid it will make the osclient re-enroll
    }.to_json
  end

  private

  def parse_body_json
    JSON.parse(request.body.read)
  end

  def valid_enroll_key?(key)
    ENROLL_SECRET == key
  end
end

Enrollment = Struct.new(:id, :host_identifier, :platform_type, :host_details, :node_key) do
  TABLE_NAME = 'enrollment'

  def self.find(id: nil, node_key: nil)
    where = "id = #{id.to_i}" if id
    where = "node_key = '#{node_key}'" if node_key

    raise 'ID or node_key are required' if where.nil?

    record = DB.execute("SELECT * FROM #{TABLE_NAME} WHERE #{where} LIMIT 1").first
    return if record.nil?

    Enrollment.new(*record)
  end

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

  def self.create(platform_type:, host_identifier:, host_details:)
    node_key = create_node_key
    DB.execute <<-SQL
      INSERT INTO #{TABLE_NAME} (platform_type, host_identifier, host_details, node_key)
      VALUES (#{platform_type.to_i}, '#{host_identifier}', '#{host_details.to_json}', '#{node_key}')
    SQL
    id = DB.execute('SELECT last_insert_rowid()').flatten.first
    Enrollment.new(id, host_identifier, platform_type.to_i, host_details.to_json, node_key)
  end

  def host_details_serialized
    JSON.parse(host_details)
  end
end
