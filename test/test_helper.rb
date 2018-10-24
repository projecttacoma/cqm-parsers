require_relative './simplecov_init'
require 'factory_girl'
require 'erubis'
require 'active_support'
require 'mongoid'
require 'mongoid/tree'
require 'uuid'
require 'builder'
require 'csv'
require 'nokogiri'
require 'ostruct'
require 'log4r'
require 'memoist'

PROJECT_ROOT = File.expand_path("../../", __FILE__)
require_relative File.join(PROJECT_ROOT, 'lib', 'hqmf-parser')

require 'minitest/autorun'
require "minitest/reporters"

require 'bundler/setup'

Mongoid.load!('config/mongoid.yml', :test)
FactoryGirl.find_definitions

class Minitest::Test
  extend Minitest::Spec::DSL
  Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

  # Add more helper methods to be used by all tests here...
  def collection_fixtures(collection, *id_attributes)
    Mongoid.session(:default)[collection].drop
    Dir.glob(File.join(File.dirname(__FILE__), 'fixtures', collection, '*.json')).each do |json_fixture_file|
      #puts "Loading #{json_fixture_file}"
      fixture_json = JSON.parse(File.read(json_fixture_file), max_nesting: 250)
      id_attributes.each do |attr|
        fixture_json[attr] = BSON::ObjectId.from_string(fixture_json[attr])
      end

      Mongoid.session(:default)[collection].insert(fixture_json)
    end
  end

  # Delete all collections from the database.
  def dump_database
    Mongoid.default_session.drop()
  end

end

class Hash
  def diff_hash(other, ignore_id=false, clean_reference=true)
    (self.keys | other.keys).inject({}) do |diff, k|
      left = self[k]
      right = other[k]
      right = right.gsub(/_precondition_\d+/, '') if (right && k==:reference && clean_reference)
      unless left == right
        if left.is_a? Hash
          if right.nil?
            tmp = left
          else
            tmp = left.diff_hash(right,ignore_id)
          end
          diff[k] = tmp unless tmp.empty?
        elsif left.is_a? Array
          tmp = []
          left.each_with_index do |entry,i|
            if (right and right[i])
              if entry.is_a? Hash
                entry_diff = entry.diff_hash(right[i],ignore_id)
              elsif left != right
                entry_diff = left.to_s
              end
            else
              entry_diff = left.to_s
            end
            tmp << entry_diff unless entry_diff.empty?
          end
          diff[k] = tmp unless tmp.empty?
        elsif(left==nil && right && right.respond_to?(:empty?) && right.empty?)
          # do nothing so nil will match an empty hash or array
        elsif(!ignore_id || (k != :id && k!="id"))
          diff[k] = {
            EXPECTED: left,
            FOUND: right
          }
        end
      end
      diff
    end
  end
end

def collection_fixtures(collection, *id_attributes)
  Dir.glob(File.join(File.dirname(__FILE__), 'fixtures', collection, '*.json')).each do |json_fixture_file|
    fixture_json = JSON.parse(File.read(json_fixture_file), max_nesting: 250)
    id_attributes.each do |attr|
      fixture_json[attr] = BSON::ObjectId.from_string(fixture_json[attr])
    end

    Mongoid.session(:default)[collection].insert(fixture_json)
  end
end

collection_fixtures('records', '_id')
collection_fixtures('measures')

# vsac-api related
APP_CONFIG = {'vsac'=> {'auth_url'=> 'https://vsac.nlm.nih.gov/vsac/ws',
                        'content_url' => 'https://vsac.nlm.nih.gov/vsac/svs',
                        'utility_url' => 'https://vsac.nlm.nih.gov/vsac',
                        'default_profile' => 'MU2 Update 2016-04-01'}}

def get_ticket_granting_ticket
  api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
  return api.ticket_granting_ticket
end