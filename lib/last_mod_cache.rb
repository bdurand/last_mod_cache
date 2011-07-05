require 'active_record'

module LastModCache
  extend ActiveSupport::Concern
  
  DYNAMIC_FINDER_METHOD_PATTERN = /^find_(all_)?by_(.+)_with_cache$/
  
  included do
    class_eval do
      class << self
        alias_method_chain(:method_missing, :last_mod_cache)
      end
    end
    class_attribute :last_mod_cache, :updated_at_column, :instance_reader => false, :instance_writer => false
    self.last_mod_cache = Rails.cache if defined?(Rails)
    self.updated_at_column = :updated_at
    
    ActiveRecord::Relation.send(:include, RelationCache) unless ActiveRecord::Relation.include?(RelationCache)
  end
  
  # Module added to ActiveRecord::Relation to add the +with_cache+ method.
  module RelationCache
    # Add +with_cache+ to the end of a relation chain to perform the find and store the results in cache.
    # Options for cache storage can be set with the optional +cache_options+ parameter. This method is
    # equivalent to calling +to_a+ on the relation so that no more relations can be chained after it is called.
    #
    # Example:
    #
    #   BlogPosts.where(:blog_id => my_blog.id).order("published_at DESC").limit(20).with_cache
    def with_cache(cache_options = nil)
      raise NotImplementedError.new("LastModCache is not available on #{klass}") unless klass.include?(LastModCache)
      bind_variables = nil
      if respond_to?(:bind_values)
        bind_variables = bind_values.collect do |column, value|
          column.type_cast(value)
        end
      end
      klass.all_with_cache(:sql => to_sql, :cache => cache_options, :bind_values => bind_variables) do
        to_a
      end
    end
  end
  
  # Class methods mixed into an ActiveRecord model that includes LastModCache.
  module ClassMethods
    # Find all records that match a query and store it in the cache. The cache entry will be invalidated whenever
    # the +updated_at+ column is advanced on any record in the table.
    #
    # The +options+ parameter can contain any options allowed in the +all+ method with the addition of a
    # <tt>:cache</tt> option which can be used to pass options to the cache itself.
    def all_with_cache(options = {}, &block)
      options = deep_clone(options)
      cache_options, options = extract_cache_options(options)
      block ||= lambda{ all(options) }
      Proxy.new do
        max_updated_at, count = max_updated_at_and_count
        records = last_mod_cache.fetch(updated_at_cache_key(:all_with_cache, options, max_updated_at, count), cache_options, &block)
        records.freeze
      end
    end
    
    # Find the first that matches a query and store it in the cache. The cache entry will be invalidated whenever
    # the +updated_at+ column on that record is changed.
    #
    # The +options+ parameter can contain any options allowed in the +first+ method with the addition of a
    # <tt>:cache</tt> option which can be used to pass options to the cache itself.
    def first_with_cache(options = {}, &block)
      options = deep_clone(options)
      cache_options, options = extract_cache_options(options)
      conditions = options.delete(:conditions)
      Proxy.new do
        id, timestamp = id_and_updated_at(conditions)
        block ||= lambda{ all(options.merge(:limit => 1, :conditions => {:id => id})).first if id }
        record = last_mod_cache.fetch(updated_at_cache_key(:first_with_cache, options.merge(:conditions => conditions), timestamp), cache_options, &block)
        record.freeze if record
      end
    end
    
    # Find a record by id or ids in database and store it in the cache. The cache entry will be invalidated whenever
    # the +updated_at+ column on that record is changed.
    #
    # The +options+ parameter can contain any options allowed in the +first+ method with the addition of a
    # <tt>:cache</tt> option which can be used to pass options to the cache
    def find_with_cache(id_or_ids, options = nil)
      options = options ? deep_clone(options) : {}
      cache_options, options = extract_cache_options(options)
      finder = lambda{ options.blank? ? find(id_or_ids) : find(id_or_ids, options) }
      if id_or_ids.is_a?(Array)
        all_with_cache(options.merge(:conditions => {:id => id_or_ids}, :cache => cache_options), &finder)
      else
        first_with_cache(options.merge(:conditions => {:id => id_or_ids}, :cache => cache_options), &finder)
      end
    end
    
    # Get the cache configuration for the class.
    def last_mod_cache_config
      if defined?(@last_mod_cache_config) && @last_mod_cache_config
        @last_mod_cache_config
      else
        superclass.last_mod_cache_config if superclass.respond_to?(:last_mod_cache_config)
      end
    end
    
    # Hook into method_missing to add "_with_cache" as a suffix to dynamic finder methods.
    def method_missing_with_last_mod_cache(method, *args, &block) #:nodoc:
      match = method.to_s.match(DYNAMIC_FINDER_METHOD_PATTERN)
      if match
        finder_column_names = match[2].split("_and_")
        finder_values = args.dup
        options = finder_values.extract_options!
        
        unless finder_column_names.size == finder_values.size
          raise ArgumentError.new("wrong number of arguments (#{finder_values.size} for #{finder_column_names.size})")
        end
        
        unless (column_names & finder_column_names).size == finder_column_names.size
          raise NoMethodError.new("dynamic finder #{method} does not exist on #{name}")
        end
        
        conditions = {}
        finder_column_names.zip(finder_values).each do |col, val|
          conditions[col] = val
        end
        options = options.merge(:conditions => conditions)
        match[1] ? all_with_cache(options) : first_with_cache(options)
      else
        method_missing_without_last_mod_cache(method, *args, &block)
      end
    end
    
    private
    
    # Construct a cache key based on a timestamp.
    def updated_at_cache_key(method, options, timestamp, row_count = nil)
      key = options.merge(:class => name, :method => method, :updated_at => timestamp.to_f)
      key[:row_count] = row_count if row_count
      key
    end
    
    # Get the maximum value in the updated at column and the count of all records in the database.
    def max_updated_at_and_count
      result = connection.select_one("SELECT MAX(#{connection.quote_column_name(updated_at_column)}) AS #{connection.quote_column_name('updated_at')}, COUNT(*) AS #{connection.quote_column_name('row_size')} FROM #{connection.quote_table_name(table_name)}")
      updated_at = result['updated_at']
      updated_at = columns_hash[updated_at_column.to_s].type_cast(updated_at) if updated_at.is_a?(String)
      [updated_at, result['row_size'].to_i]
    end
    
    # Get the id and updated at value for the first row that matches the conditions.
    def id_and_updated_at(conditions)
      column = columns_hash[updated_at_column.to_s]
      sql = "SELECT #{connection.quote_column_name(primary_key)} AS #{connection.quote_column_name('id')}, #{connection.quote_column_name(updated_at_column)} AS #{connection.quote_column_name('updated_at')} FROM #{connection.quote_table_name(table_name)}"
      sql << " WHERE #{sanitize_sql_for_conditions(conditions)}" if conditions
      result = connection.select_one(sql)
      if result
        updated_at = result['updated_at']
        updated_at = columns_hash[updated_at_column.to_s].type_cast(updated_at) if updated_at.is_a?(String)
        [result['id'], updated_at]
      else
        []
      end
    end
    
    # Pull the :cache options from the options hash.
    def extract_cache_options(options)
      if options.include?(:cache)
        options.dup
        cache_options = options.delete(:cache)
        [cache_options, options]
      else
        [{}, options]
      end
    end
    
    # Create a deep clone of a hash where all values are cloned as well. This is used
    # to isolate any hash values sent to a Proxy object so that the values can't be changed
    # after the Proxy is created.
    def deep_clone(obj)
      case obj
      when Hash
        clone = {}
        obj.each do |k, v|
          clone[k] = deep_clone(v)
        end
        obj = clone
      when Array
        obj.collect{|a| deep_clone(a)}
      when String
        obj.clone
      else
        obj
      end
    end
  end
  
  module InstanceMethods
    # Force an update to the timestamp column. This method can be invoked to force cache entries to expire.
    # Validations and callbacks will *not* be called. If you need those called, simply call +update_attribute+ instead.
    def update_timestamp!
      col_name = self.class.updated_at_column
      self.send("#{col_name}=", Time.now)
      timestamp = self.send(col_name)
      conn = self.class.connection
      sql = self.class.send(:sanitize_sql, ["UPDATE #{conn.quote_table_name(self.class.table_name)} SET #{conn.quote_column_name(col_name)} = ? WHERE #{conn.quote_column_name(self.class.primary_key)} = ?", timestamp, id])
      conn.update(sql)
    end
  end
  
  # Proxy class that sends all method calls to a block.
  class Proxy #:nodoc:
    required_methods = {"__send__" => true, "__id__" => true}
    instance_methods.each do |m|
      undef_method(m) unless required_methods.include?(m.to_s)
    end
    
    def initialize(&block)
      @block = block
    end
    
    def method_missing(method, *args, &block)
      @object = @block.call unless defined?(@object)
      @object.send(method, *args, &block)
    end
  end
end
