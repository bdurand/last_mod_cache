require 'sqlite3'

active_record_version = ENV["ACTIVE_RECORD_VERSION"] || [">= 3.0.0"]
active_record_version = [active_record_version] unless active_record_version.is_a?(Array)
gem 'activerecord', *active_record_version

require File.expand_path("../../lib/last_mod_cache.rb", __FILE__)

puts "Testing with activerecord #{ActiveRecord::VERSION::STRING}"

module Rails
  def self.cache
    unless defined?(@cache)
      @cache = ActiveSupport::Cache::MemoryStore.new
    end
    @cache
  end
end

module LastModCache
  module Test
    class << self
      def setup
        ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
        Thing.setup
        Widget.setup
        ModelOne.setup
        ModelTwo.setup
        ModelFour.setup
      end
      
      def cache
        unless defined?(@cache)
          @cache = ActiveSupport::Cache::MemoryStore.new
        end
        @cache
      end
    end
    
    module PokeRecordValue
      def poke_column_value(id, column, value)
        sql = ["UPDATE #{connection.quote_table_name(table_name)} SET #{connection.quote_column_name(column)} = ? WHERE id = ?", value, id]
        connection.update(sanitize_sql_array(sql))
      end
    end
    
    class Thing < ActiveRecord::Base
      belongs_to :widget
      
      class << self
        def setup
          connection.create_table(table_name) do |t|
            t.string :name
            t.integer :model_one_id
            t.integer :widget_id
            t.datetime :updated_at
          end
        end
      end
    end
    
    class Widget < ActiveRecord::Base
      class << self
        def setup
          connection.create_table(table_name) do |t|
            t.string :name
            t.datetime :updated_at
          end
        end
      end
    end
    
    class ModelOne < ActiveRecord::Base
      extend PokeRecordValue
      include LastModCache
      
      has_many :things
      belongs_to :widget
      
      class << self
        def setup
          connection.create_table(table_name) do |t|
            t.string :name
            t.integer :value
            t.integer :widget_id
            t.datetime :updated_at
          end
        end
      end
    end

    class ModelTwo < ActiveRecord::Base
      extend PokeRecordValue
      include LastModCache
      self.updated_at_column = :modified_at
      self.last_mod_cache = Test.cache
      
      before_save{|r| r.modified_at = Time.now}
      
      class << self
        def setup
          connection.create_table(table_name) do |t|
            t.string :name
            t.integer :value
            t.string :type
            t.datetime :modified_at
          end
        end
      end
    end
    
    class ModelThree < ModelTwo
    end

    class ModelFour < ActiveRecord::Base
      extend PokeRecordValue
      include LastModCache
      self.updated_at_column = :last_modified
      
      before_save{|r| r.last_modified = Time.now.to_f}
      
      class << self
        def setup
          connection.create_table(table_name) do |t|
            t.string :name
            t.integer :value
            t.float :last_modified
          end
        end
      end
    end
  end
end

LastModCache::Test.setup
