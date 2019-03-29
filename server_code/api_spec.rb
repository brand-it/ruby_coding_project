# frozen_string_literal: true

require 'rack/test'
require 'rspec'
require_relative 'setup_db'

ENV['RACK_ENV'] = 'test'

module RSpecMixin
  include Rack::Test::Methods

  def app
    described_class
  end
end

RSpec.configure do |c|
  c.include RSpecMixin
end

require_relative 'api'

describe FleetManager do
  let(:host_details) do
    {
      'os_version' => {
        'build' => '18D109',
        'major' => '10',
        'minor' => '14',
        'name' => 'Mac OS X',
        'patch' => '3',
        'platform' => 'darwin',
        'platform_like' => 'darwin',
        'version' => '10.14.3'
      }
    }
  end
  let(:host_identifier) { 'A936D043-D3EF-513E-A9F0-2A09C239C050' }
  let(:platform_type) { '21' }
  let(:create) do
    Enrollment.create(
      platform_type: platform_type,
      host_identifier: host_identifier,
      host_details: host_details
    )
  end
  let(:valid_enroll_json) do
    {
      enroll_secret: 'somesecret'
    }.to_json
  end
  let(:invalid_enroll_json) do
    {
      enroll_secret: 'Rob A. Bank'
    }.to_json
  end

  describe 'POST /enroll' do
    let(:json) { JSON.parse(enroll.body) }

    context 'when enroll_key is invalid' do
      subject(:enroll) { post '/enroll', invalid_enroll_json }

      it { expect(json['node_invalid']).to eq true }
      it { expect(json['node_key']).to eq nil }
    end

    context 'when enroll_key is valid' do
      subject(:enroll) { post '/enroll', valid_enroll_json }

      it { expect(json['node_invalid']).to eq false }
      it { expect(json['node_key']).to eq Enrollment.all.last.node_key }
    end
  end

  describe 'POST /configuration' do
    let(:json) { JSON.parse(configuration.body) }

    context 'when enrolled' do
      subject(:configuration) { post '/configuration', { node_key: create.node_key }.to_json }

      it { expect(json).to eq JSON.parse(File.read('config.json')) }
    end

    context 'when not enrolled' do
      subject(:configuration) { post '/configuration', { node_key: 'made_up_key' }.to_json }

      it { expect(json['node_invalid']).to eq true }
    end
  end

  describe 'Enrollment.find' do
    subject(:find) { Enrollment.find(id: create.id) }
    it { expect(find.id).to eq create.id }
    it { expect(find.platform_type).to eq create.platform_type }
    it { expect(find.host_identifier).to eq create.host_identifier }
    it { expect(find.host_details).to eq create.host_details }
    it { expect(find.host_details_serialized).to eq create.host_details_serialized }
  end

  describe 'Enrollment.create' do
    it { expect(create).to be_a(Enrollment) }
    it { expect(create.platform_type).to eq platform_type.to_i }
    it { expect(create.host_identifier).to eq host_identifier }
    it { expect(create.host_details).to eq host_details.to_json }
    it { expect(create.host_details_serialized).to eq host_details }
    it { expect(create.id).to_not be_nil }
  end
end

# JUST so I can use as reference
# {
#   "enroll_secret": "somesecret",
#   "host_identifier": "A936D043-D3EF-513E-A9F0-2A09C239C050",
#   "platform_type": "21",
#   "host_details": {
#     "os_version": {
#       "build": "18D109",
#       "major": "10",
#       "minor": "14",
#       "name": "Mac OS X",
#       "patch": "3",
#       "platform": "darwin",
#       "platform_like": "darwin",
#       "version": "10.14.3"
#     },
#     "osquery_info": {
#       "build_distro": "10.12",
#       "build_platform": "darwin",
#       "config_hash": "",
#       "config_valid": "0",
#       "extensions": "inactive",
#       "instance_id": "dc6630d5-6e92-4716-929d-6f0b7cded84c",
#       "pid": "13862",
#       "start_time": "1553877901",
#       "uuid": "A936D043-D3EF-513E-A9F0-2A09C239C050",
#       "version": "3.2.6",
#       "watcher": "-1"
#     },
#     "platform_info": {
#       "address": "0xff969000",
#       "date": "09/28/2018 ",
#       "extra": "IM183.88Z.F000.B00.1809280842; IM183; 166.0.0.0.0; _atsserver@xapp157; Fri Sep 28 08:42:57 2018; 166 (B&I); F000_B00; Official Build, RELEASE; Apple LLVM version 6.1.0 (clang-602.0.53) (based on LLVM 3.6.0svn)",
#       "revision": "166 (B&I)",
#       "size": "8388608",
#       "vendor": "Apple Inc. ",
#       "version": "166.0.0.0.0 ",
#       "volume_size": "1486848"
#     },
#     "system_info": {
#       "computer_name": "",
#       "cpu_brand": "Intel(R) Core(TM) i7-7700K CPU @ 4.20GHz\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000",
#       "cpu_logical_cores": "8",
#       "cpu_physical_cores": "4",
#       "cpu_subtype": "Intel x86-64h Haswell",
#       "cpu_type": "x86_64h",
#       "hardware_model": "iMac18,3 ",
#       "hardware_serial": "D25VD0WNJ1GQ",
#       "hardware_vendor": "Apple Inc. ",
#       "hardware_version": "1.0 ",
#       "hostname": "localhost.localdomain",
#       "local_hostname": "Brandts-iMac",
#       "physical_memory": "42949672960",
#       "uuid": "A936D043-D3EF-513E-A9F0-2A09C239C050"
#     }
#   }
# }
