require 'spec_helper'

describe LastModCache do
  before :each do
    LastModCache::Test::ModelOne.delete_all
    LastModCache::Test::ModelTwo.delete_all
    LastModCache::Test::ModelThree.delete_all
    LastModCache::Test::ModelFour.delete_all
    Rails.cache.clear
    LastModCache::Test.cache.clear
  end
  
  let(:model_one_record_one){LastModCache::Test::ModelOne.create!(:name => "one", :value => 1)}
  let(:model_one_record_two){LastModCache::Test::ModelOne.create!(:name => "two", :value => 2)}
  let(:model_one_record_three){LastModCache::Test::ModelOne.create!(:name => "three", :value => 3)}
  
  let(:model_two_record_one){LastModCache::Test::ModelTwo.create!(:name => "one", :value => 1)}
  let(:model_two_record_two){LastModCache::Test::ModelTwo.create!(:name => "two", :value => 2)}
  let(:model_two_record_three){LastModCache::Test::ModelTwo.create!(:name => "three", :value => 3)}
  
  let(:model_three_record_one){LastModCache::Test::ModelThree.create!(:name => "one", :value => 1)}
  let(:model_three_record_two){LastModCache::Test::ModelThree.create!(:name => "two", :value => 2)}
  let(:model_three_record_three){LastModCache::Test::ModelThree.create!(:name => "three", :value => 3)}
  
  let(:model_four_record_one){LastModCache::Test::ModelFour.create!(:name => "one", :value => 1)}
  let(:model_four_record_two){LastModCache::Test::ModelFour.create!(:name => "two", :value => 2)}
  let(:model_four_record_three){LastModCache::Test::ModelFour.create!(:name => "three", :value => 3)}
  
  context "configuration" do
    it "should use Rails.cache by default" do
      LastModCache::Test::ModelOne.last_mod_cache.should == Rails.cache
    end
    
    it "should be able to set the cache" do
      LastModCache::Test::ModelTwo.last_mod_cache.should == LastModCache::Test.cache
    end
    
    it "should inherit the cache from a parent class" do
      LastModCache::Test::ModelThree.last_mod_cache.should == LastModCache::Test.cache
    end
    
    it "should use update_at as the default updated at column" do
      LastModCache::Test::ModelOne.updated_at_column.should == :updated_at
    end
    
    it "should be able to set the updated at column" do
      LastModCache::Test::ModelTwo.updated_at_column.should == :modified_at
    end
    
    it "should inherit the updated at column from a parent class" do
      LastModCache::Test::ModelThree.updated_at_column.should == :modified_at
    end
  end

  context "updating the timestamp" do
    it "should update" do
      t = model_one_record_one.updated_at
      model_one_record_one.update_timestamp!
      model_one_record_one.updated_at.should > t
      model_one_record_one.reload
      model_one_record_one.updated_at.should > t
    end
    
    it "should update when using a custom update at column" do
      t = model_two_record_one.modified_at
      model_two_record_one.update_timestamp!
      model_two_record_one.modified_at.should > t
      model_two_record_one.reload
      model_two_record_one.modified_at.should > t
    end
    
    it "should update when using a non-datetime column" do
      t = model_four_record_one.last_modified
      model_four_record_one.update_timestamp!
      model_four_record_one.last_modified.should > t
      model_four_record_one.reload
      model_four_record_one.last_modified.should > t
    end
  end
  
  context "cache key information" do
    it "should get the maximum updated at timestamp and the count of all rows in a table" do
      model_one_record_one
      model_one_record_two
      model_one_record_two.updated_at.should_not be_nil
      LastModCache::Test::ModelOne.max_updated_at_and_count.should == [model_one_record_two.updated_at, 2]
      
      model_one_record_three
      LastModCache::Test::ModelOne.max_updated_at_and_count.should == [model_one_record_three.updated_at, 3]
    end
    
    it "should get the maximum updated at timestamp and the count of all rows in a table when using a custom timestamp column" do
      model_four_record_one
      model_four_record_two
      model_four_record_two.last_modified.should_not be_nil
      LastModCache::Test::ModelFour.max_updated_at_and_count.should == [model_four_record_two.last_modified, 2]
      
      model_four_record_three
      LastModCache::Test::ModelFour.max_updated_at_and_count.should == [model_four_record_three.last_modified, 3]
    end
  end
  
  context "find all" do
    before :each do
      model_one_record_one
      model_one_record_two
      model_one_record_three
    end
    
    it "should find all records with a query and put them in the cache" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {:name => ["one", "two"]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => ["one", "two"]}).should == [model_one_record_one, model_one_record_two]
      Rails.cache.read(cache_key).should == [model_one_record_one, model_one_record_two]
    end
    
    it "should find all records with a query from the cache" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {:name => ["one", "two"]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      Rails.cache.write(cache_key, [model_one_record_one, model_one_record_two])
      LastModCache::Test::ModelOne.poke_column_value(model_one_record_two.id, :value, 0)
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => ["one", "two"]}).collect{|r| r.value}.should == [1, 2]
    end
    
    it "should pass :cache option through to the cache" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {:name => ["two"]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      Rails.cache.write(cache_key, [model_one_record_two], :namespace => "test")
      LastModCache::Test::ModelOne.poke_column_value(model_one_record_two.id, :value, 0)
      LastModCache::Test::ModelOne.all_with_cache(:cache => {:namespace => "test"}, :conditions => {:name => ["two"]}).collect{|r| r.value}.should == [2]
    end
    
    it "should invalidate a find all cache whenever any record is modified" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {:name => ["one", "two"]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      Rails.cache.write(cache_key, [model_one_record_one, model_one_record_two])
      LastModCache::Test::ModelOne.poke_column_value(model_one_record_two.id, :value, 0)
      model_one_record_three.update_attribute(:value, 4)
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => ["one", "two"]}).collect{|r| r.value}.should == [1, 0]
    end
    
    it "should invalidate a find all cache whenever any record is deleted" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {:name => ["two", "three"]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      Rails.cache.write(cache_key, [model_one_record_one, model_one_record_two])
      LastModCache::Test::ModelOne.poke_column_value(model_one_record_two.id, :value, 0)
      model_one_record_one.destroy
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => ["two", "three"]}).collect{|r| r.value}.should == [0, 3]
    end
    
    it "should work with models that don't use the defaults" do
      model_two_record_one
      model_two_record_two
      model_two_record_three
      
      timestamp = Time.now - 60
      LastModCache::Test::ModelTwo.poke_column_value(model_two_record_two.id, :modified_at, timestamp)
      model_two_record_two.reload
      LastModCache::Test::ModelTwo.all_with_cache(:conditions => {:name => "two"}).collect{|r| r.value}.should == [2]
      
      cache_key = {:class => "LastModCache::Test::ModelTwo", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelTwo.maximum(:modified_at).to_f, :conditions => {:name => "two"}, :row_count => 3}
      LastModCache::Test.cache.write(cache_key, [model_two_record_two.dup])
      LastModCache::Test::ModelTwo.poke_column_value(model_two_record_two.id, :value, 0)
      LastModCache::Test::ModelTwo.all_with_cache(:conditions => {:name => "two"}).collect{|r| r.value}.should == [2]
      
      model_two_record_two.update_attribute(:value, 5)
      model_two_record_two.reload
      LastModCache::Test::ModelTwo.all_with_cache(:conditions => {:name => "two"}).collect{|r| r.value}.should == [5]
      LastModCache::Test.cache.read(cache_key.merge(:updated_at => LastModCache::Test::ModelTwo.maximum(:modified_at).to_f)).should == [model_two_record_two]
    end
    
    it "should work with a numeric timestamp column" do
      model_four_record_one
      model_four_record_two
      model_four_record_three
      
      cache_key = {:class => "LastModCache::Test::ModelFour", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelFour.maximum(:last_modified), :conditions => {:name => "two"}, :row_count => 3}
      Rails.cache.write(cache_key, [model_four_record_two.dup])
      LastModCache::Test::ModelFour.poke_column_value(model_four_record_two.id, :value, 0)
      LastModCache::Test::ModelFour.all_with_cache(:conditions => {:name => "two"}).collect{|r| r.value}.should == [2]
      
      model_four_record_two.update_attribute(:value, 5)
      model_four_record_two.reload
      LastModCache::Test::ModelFour.all_with_cache(:conditions => {:name => "two"}).collect{|r| r.value}.should == [5]
      Rails.cache.read(cache_key.merge(:updated_at => LastModCache::Test::ModelFour.maximum(:last_modified).to_f)).should == [model_four_record_two]
    end
    
    it "should be lazy loaded" do
      Rails.cache.should_not_receive(:read)
      Rails.cache.should_not_receive(:write)
      LastModCache::Test::ModelOne.should_not_receive(:connection)
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => ["one", "two"]})
      nil
    end
    
    it "should always return a frozen object" do
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => "two"}).should be_frozen
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => "four"}).should be_frozen
    end
    
    it "should not require any options" do
      LastModCache::Test::ModelOne.all_with_cache.should == LastModCache::Test::ModelOne.all
    end
  end
  
  context "find one by query" do
    before :each do
      model_one_record_one
      model_one_record_two
      model_one_record_three
    end
    
    it "should find a single record with a query and put it in the cache" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :updated_at => model_one_record_two.updated_at.to_f, :conditions => {:name => "two"}}
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "two"}).should == model_one_record_two
      Rails.cache.read(cache_key).should == model_one_record_two
    end
    
    it "should find a single record with a query from the cache" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :updated_at => model_one_record_two.updated_at.to_f, :conditions => {:name => "two"}}
      Rails.cache.write(cache_key, model_one_record_two)
      LastModCache::Test::ModelOne.poke_column_value(model_one_record_two.id, :value, 0)
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "two"}).value.should == 2
    end
    
    it "should invalidate a single record query cache entry when the record is modified" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :updated_at => model_one_record_two.updated_at.to_f, :conditions => {:name => "two"}}
      Rails.cache.write(cache_key, model_one_record_two)
      model_one_record_two.update_attribute(:value, 0)
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "two"}).value.should == 0
    end
    
    it "should not find a record by query if the updated time for the record could not be found" do
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "not found"}).should == nil
    end
    
    it "should not find a record by query if it has been deleted since it was cached" do
      model_one_record_two
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "two"}).should == model_one_record_two
      model_one_record_two.destroy
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "two"}).should == nil
    end
    
    it "should work with models that don't use the defaults" do
      model_four_record_one
      model_four_record_two
      model_four_record_three
      
      timestamp = Time.now - 60
      LastModCache::Test::ModelTwo.poke_column_value(model_two_record_two.id, :modified_at, timestamp)
      model_two_record_two.reload
      LastModCache::Test::ModelTwo.first_with_cache(:conditions => {:name => "two"}).value.should == 2
      
      cache_key = {:class => "LastModCache::Test::ModelTwo", :method => :first_with_cache, :updated_at => timestamp.to_f, :conditions => {:name => "two"}}
      LastModCache::Test.cache.write(cache_key, model_two_record_two.dup)
      LastModCache::Test::ModelTwo.poke_column_value(model_two_record_two.id, :value, 0)
      LastModCache::Test::ModelTwo.first_with_cache(:conditions => {:name => "two"}).value.should == 2
      
      model_two_record_two.update_attribute(:value, 5)
      model_two_record_two.reload
      LastModCache::Test::ModelTwo.first_with_cache(:conditions => {:name => "two"}).value.should == 5
      LastModCache::Test.cache.read(cache_key.merge(:updated_at => model_two_record_two.modified_at.to_f)).should == model_two_record_two
    end
    
    it "should work with a numeric timestamp column" do
      model_four_record_one
      model_four_record_two
      model_four_record_three
      
      cache_key = {:class => "LastModCache::Test::ModelFour", :method => :first_with_cache, :updated_at => model_four_record_two.last_modified, :conditions => {:name => "two"}}
      Rails.cache.write(cache_key, model_four_record_two.dup)
      LastModCache::Test::ModelFour.poke_column_value(model_four_record_two.id, :value, 0)
      LastModCache::Test::ModelFour.first_with_cache(:conditions => {:name => "two"}).value.should == 2
      
      model_four_record_two.update_attribute(:value, 5)
      model_four_record_two.reload
      LastModCache::Test::ModelFour.first_with_cache(:conditions => {:name => "two"}).value.should == 5
      Rails.cache.read(cache_key.merge(:updated_at => model_four_record_two.last_modified)).should == model_four_record_two
    end
    
    it "should be lazy loaded" do
      Rails.cache.should_not_receive(:read)
      Rails.cache.should_not_receive(:write)
      LastModCache::Test::ModelOne.should_not_receive(:connection)
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "two"})
      nil
    end
    
    it "should always return a frozen object or nil" do
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "two"}).should be_frozen
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "four"}).should == nil
    end
    
    it "should not require any options" do
      LastModCache::Test::ModelOne.first_with_cache.should == LastModCache::Test::ModelOne.first
    end
  end
  
  context "find by id" do
    before :each do
      model_one_record_one
      model_one_record_two
      model_one_record_three
    end
    
    it "should find a single record by id and put it in the cache" do
      model_one_record_one
      model_one_record_two
      model_one_record_three
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :conditions => {"id" => model_one_record_two.id}, :updated_at => model_one_record_two.updated_at.to_f}
      LastModCache::Test::ModelOne.find_with_cache(model_one_record_two.id).should == model_one_record_two
      Rails.cache.read(cache_key).should == model_one_record_two
    end
    
    it "should find a single record by id from the cache" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :conditions => {"id" => model_one_record_two.id}, :updated_at => model_one_record_two.updated_at.to_f}
      Rails.cache.write(cache_key, model_one_record_two)
      LastModCache::Test::ModelOne.poke_column_value(model_one_record_two.id, :value, 0)
      LastModCache::Test::ModelOne.find_with_cache(model_one_record_two.id).value.should == 2
    end
    
    it "should invalidate a single record by id cache entry when the record is modified" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :conditions => {"id" => model_one_record_two.id}, :updated_at => model_one_record_two.updated_at.to_f}
      Rails.cache.write(cache_key, model_one_record_two)
      model_one_record_two.update_attribute(:value, 0)
      LastModCache::Test::ModelOne.find_with_cache(model_one_record_two.id).value.should == 0
    end
    
    it "should find multiple records by id and put them in the cache" do
      model_one_record_one
      model_one_record_two
      model_one_record_three
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {"id" => [model_one_record_one.id, model_one_record_two.id]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      LastModCache::Test::ModelOne.find_with_cache([model_one_record_one.id, model_one_record_two.id]).should == [model_one_record_one, model_one_record_two]
      Rails.cache.read(cache_key).should == [model_one_record_one, model_one_record_two]
    end
    
    it "should find multiple records by id from the cache" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {"id" => [model_one_record_one.id, model_one_record_two.id]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      Rails.cache.write(cache_key, [model_one_record_one, model_one_record_two])
      LastModCache::Test::ModelOne.poke_column_value(model_one_record_one.id, :value, 0)
      LastModCache::Test::ModelOne.find_with_cache([model_one_record_one.id, model_one_record_two.id]).first.value.should == 1
    end
    
    it "should invalidate a multiple records by id cache entry when any record is modified" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {"id" => [model_one_record_one.id, model_one_record_two.id]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      Rails.cache.write(cache_key, [model_one_record_one, model_one_record_two])
      model_one_record_one.update_attribute(:value, 0)
      LastModCache::Test::ModelOne.find_with_cache([model_one_record_one.id, model_one_record_two.id]).first.value.should == 0
    end
    
    it "should invalidate a multiple records by id cache entry when any record is deleted" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {"id" => [model_one_record_one.id, model_one_record_three.id]}, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      Rails.cache.write(cache_key, [model_one_record_one, model_one_record_three])

      LastModCache::Test::ModelOne.poke_column_value(model_one_record_one.id, :value, 0)
      model_one_record_two.destroy
      LastModCache::Test::ModelOne.find_with_cache([model_one_record_one.id, model_one_record_three.id]).first.value.should == 0
    end
    
    it "should raise a RecordNotFound error if a record could not be found" do
      lambda{LastModCache::Test::ModelOne.find_with_cache(-1).nil?}.should raise_error(ActiveRecord::RecordNotFound)
    end
    
    it "should raise a RecordNotFound error if any of the records can't be found" do
      lambda{LastModCache::Test::ModelOne.find_with_cache([model_one_record_one.id, -1]).nil?}.should raise_error(ActiveRecord::RecordNotFound)
    end
    
    it "should raise a RecordNotFound error if the record has been deleted since it was cached" do
      model_one_record_two
      LastModCache::Test::ModelOne.find_with_cache(model_one_record_two.id).should == model_one_record_two
      model_one_record_two.destroy
      lambda{LastModCache::Test::ModelOne.find_with_cache(model_one_record_two.id).nil?}.should raise_error(ActiveRecord::RecordNotFound)
    end
    
    it "should work with models that don't use the defaults" do
      model_four_record_one
      model_four_record_two
      model_four_record_three
      
      timestamp = Time.now - 60
      LastModCache::Test::ModelTwo.poke_column_value(model_two_record_two.id, :modified_at, timestamp)
      model_one_record_two.reload
      LastModCache::Test::ModelTwo.find_with_cache(model_two_record_two.id).value.should == 2
      
      cache_key = {:class => "LastModCache::Test::ModelTwo", :method => :first_with_cache, :conditions => {"id" => model_two_record_two.id}, :updated_at => model_one_record_two.updated_at.to_f}
      LastModCache::Test.cache.write(cache_key, model_two_record_two.dup)
      LastModCache::Test::ModelTwo.poke_column_value(model_two_record_two.id, :value, 0)
      LastModCache::Test::ModelTwo.find_with_cache(model_two_record_two.id).value.should == 2
      
      model_two_record_two.update_attribute(:value, 5)
      model_two_record_two.reload
      LastModCache::Test::ModelTwo.find_with_cache(model_two_record_two.id).value.should == 5
      LastModCache::Test.cache.read(cache_key.merge(:updated_at => model_two_record_two.modified_at.to_f)).should == model_two_record_two
    end
    
    it "should be lazy loaded" do
      Rails.cache.should_not_receive(:read)
      Rails.cache.should_not_receive(:write)
      LastModCache::Test::ModelOne.should_not_receive(:connection)
      LastModCache::Test::ModelOne.find_with_cache(model_one_record_two.id)
      LastModCache::Test::ModelOne.find_with_cache([model_one_record_one.id, model_one_record_two.id])
      nil
    end
  end
  
  context "dynamic query methods" do
    before :each do
      model_one_record_one
      model_one_record_two
      model_one_record_three
    end
    
    it "should pass dynamic find methods through the cache" do
      relation = LastModCache::Test::ModelOne.where(:name => "two").limit(1)
      LastModCache::Test::ModelOne.find_by_name_with_cache("two").should == model_one_record_two
      timestamp = model_one_record_two.updated_at
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :updated_at => timestamp.to_f, :conditions => {"name" => "two"}}
      Rails.cache.read(cache_key).should == model_one_record_two
    end
    
    it "should pass dynamic find_all methods through the cache" do
      LastModCache::Test::ModelOne.find_all_by_name_with_cache("two").should == [model_one_record_two]
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3, :conditions => {"name" => "two"}}
      Rails.cache.read(cache_key).should == [model_one_record_two]
    end
    
    it "should pass dynamic find methods with multiple conditions through the cache" do
      model_one_record_one.update_attribute(:name, "two")
      model_one_record_three.update_attribute(:name, "two")
      LastModCache::Test::ModelOne.find_by_name_and_value_with_cache("two", 2).should == model_one_record_two
      timestamp = model_one_record_two.updated_at
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :updated_at => timestamp.to_f, :conditions => {"name" => "two", "value" => 2}}
      Rails.cache.read(cache_key).should == model_one_record_two
    end
    
    it "should pass dynamic find_all methods with multiple conditions through the cache" do
      model_one_record_one.update_attribute(:name, "two")
      model_one_record_three.update_attribute(:name, "two")
      LastModCache::Test::ModelOne.find_all_by_name_and_value_with_cache("two", 2).should == [model_one_record_two]
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3, :conditions => {"name" => "two", "value" => 2}}
      Rails.cache.read(cache_key).should == [model_one_record_two]
    end
    
    it "should not interfere with normal method missing behavior" do
      LastModCache::Test::ModelOne.find_by_name("one").should == model_one_record_one
      LastModCache::Test::ModelOne.find_by_name_and_value("one", 1).should == model_one_record_one
      lambda{ LastModCache::Test::ModelOne.this_is_not_a_method }.should raise_error(NoMethodError)
    end
    
    it "should raise an error when the wrong number of arguments are passed" do
      lambda{ LastModCache::Test::ModelOne.find_by_name_with_cache("one", 1) }.should raise_error(ArgumentError)
      lambda{ LastModCache::Test::ModelOne.find_by_name_with_cache }.should raise_error(ArgumentError)
    end
    
    it "should raise an error if a column doesn not exist" do
      lambda{ LastModCache::Test::ModelOne.find_by_fleevium_with_cache("bloork") }.should raise_error(NoMethodError)
      lambda{ LastModCache::Test::ModelOne.find_by_name_and_stuff_with_cache("one", :x) }.should raise_error(NoMethodError)
    end
    
    it "should be lazy loaded" do
      Rails.cache.should_not_receive(:read)
      Rails.cache.should_not_receive(:write)
      LastModCache::Test::ModelOne.should_not_receive(:connection)
      LastModCache::Test::ModelOne.find_by_name_and_value_with_cache("one", 1)
      LastModCache::Test::ModelOne.find_all_by_name_with_cache("one")
      nil
    end
  end
  
  context ActiveRecord::Relation do
    before :each do
      model_one_record_one
      model_one_record_two
      model_one_record_three
    end
    
    it "should cache the result of a relation chain" do
      relation = LastModCache::Test::ModelOne.where(:name => ["one", "two"]).order("value DESC")
      relation.with_cache.should == [model_one_record_two, model_one_record_one]
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3, :sql => relation.to_sql, :bind_values => []}
      Rails.cache.read(cache_key).should == [model_one_record_two, model_one_record_one]
      Rails.cache.write(cache_key, [model_one_record_one, model_one_record_three])
      relation.with_cache.should == [model_one_record_one, model_one_record_three]
    end
    
    it "should cache the result using bind variables if supported" do
      name_column = LastModCache::Test::ModelOne.columns_hash["name"]
      relation = LastModCache::Test::ModelOne.where("name IN (?, ?)")
      if relation.respond_to?(:bind_values)
        bind_relation = relation.bind([name_column, "one"]).bind([name_column, "two"]).order("value DESC")
        bind_relation.with_cache.should == [model_one_record_two, model_one_record_one]
        cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3, :sql => bind_relation.to_sql, :bind_values => ["one", "two"]}
        Rails.cache.read(cache_key).should == [model_one_record_two, model_one_record_one]
        Rails.cache.write(cache_key, [model_one_record_one, model_one_record_three])
        bind_relation.with_cache.should == [model_one_record_one, model_one_record_three]
      else
        pending("ActiveRecord #{ActiveRecord::VERSION::STRING} does not support bind variables")
      end
    end
    
    it "should be lazy loaded" do
      Rails.cache.should_not_receive(:read)
      Rails.cache.should_not_receive(:write)
      LastModCache::Test::ModelOne.should_not_receive(:connection)
      LastModCache::Test::ModelOne.where(:name => "one").with_cache
      nil
    end
  end
  
  context "associations" do
    before :each do
      model_one_record_two.things.create(:name => "thing_0")
      LastModCache::Test::Widget.create!(:name => "widget_0")
      model_one_record_one.widget = widget
      LastModCache::Test::Widget.create!(:name => "widget_2")
      model_one_record_one.things.create(:name => "thing_1")
      model_one_record_one.things.create(:name => "thing_2")
      model_one_record_one.save!
      model_one_record_one.reload
      model_one_record_three.things.create(:name => "thing_3")
    end
    
    let(:widget){ LastModCache::Test::Widget.create!(:name => "widget_1") }
    let(:includes){ [:widget, {:things => :widget}] }
    
    it "should cache belongs_to associations" do
      model_one_record_one.widget_with_cache.name.should == "widget_1"
      cache_key = {:class => "LastModCache::Test::Widget", :method => :first_with_cache, :updated_at => widget.updated_at.to_f, :conditions => {"id" => widget.id}}
      Rails.cache.read(cache_key).name.should == "widget_1"
      Rails.cache.write(cache_key, LastModCache::Test::Widget.new(:name => "widget_a"))
      model_one_record_one.widget_with_cache.name.should == "widget_a"
    end
    
    it "should cache included associations when finding many records" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :conditions => {:name => "one"}, :include => includes, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3}
      LastModCache::Test::ModelOne.all_with_cache(:conditions => {:name => "one"}, :include => includes).should == [model_one_record_one]
      cached = Rails.cache.read(cache_key).first
      if cached.respond_to?(:association)
        cached.association(:widget).loaded?.should == true
        cached.association(:things).loaded?.should == true
        cached.things.first.association(:widget).loaded?.should == true
      else
        cached.widget.loaded?.should == true
        cached.things.loaded?.should == true
      end
    end
    
    it "should cache included associations when finding one record" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :conditions => {:name => "one"}, :include => includes, :updated_at => model_one_record_one.updated_at.to_f}
      LastModCache::Test::ModelOne.first_with_cache(:conditions => {:name => "one"}, :include => includes).should == model_one_record_one
      cached = Rails.cache.read(cache_key)
      if cached.respond_to?(:association)
        cached.association(:widget).loaded?.should == true
        cached.association(:things).loaded?.should == true
        cached.things.first.association(:widget).loaded?.should == true
      else
        cached.widget.loaded?.should == true
        cached.things.loaded?.should == true
      end
    end
    
    it "should cache included associations when finding a record by id" do
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :first_with_cache, :conditions => {"id" => model_one_record_one.id}, :include => includes, :updated_at => model_one_record_one.updated_at.to_f}
      LastModCache::Test::ModelOne.find_with_cache(model_one_record_one.id, :include => includes).should == model_one_record_one
      cached = Rails.cache.read(cache_key)
      if cached.respond_to?(:association)
        cached.association(:widget).loaded?.should == true
        cached.association(:things).loaded?.should == true
        cached.things.first.association(:widget).loaded?.should == true
      else
        cached.widget.loaded?.should == true
        cached.things.loaded?.should == true
      end
    end
    
    it "should cache included associations when finding with a Relation" do
      relation = LastModCache::Test::ModelOne.where(:name => "one").includes(includes)
      relation.with_cache.should == [model_one_record_one]
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3, :sql => relation.to_sql, :bind_values => []}
      cached = Rails.cache.read(cache_key).first
      if cached.respond_to?(:association)
        cached.association(:widget).loaded?.should == true
        cached.association(:things).loaded?.should == true
        cached.things.first.association(:widget).loaded?.should == true
      else
        cached.widget.loaded?.should == true
        cached.things.loaded?.should == true
      end
    end
    
    it "should cache eager load associations when finding with a Relation" do
      relation = LastModCache::Test::ModelOne.where(:name => "one").eager_load(includes)
      relation.with_cache.should == [model_one_record_one]
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3, :sql => relation.to_sql, :bind_values => []}
      cached = Rails.cache.read(cache_key).first
      if cached.respond_to?(:association)
        cached.association(:widget).loaded?.should == true
        cached.association(:things).loaded?.should == true
        cached.things.first.association(:widget).loaded?.should == true
      else
        cached.widget.loaded?.should == true
        cached.things.loaded?.should == true
      end
    end
    
    it "should cache preload associations when finding with a Relation" do
      relation = LastModCache::Test::ModelOne.where(:name => "one").preload(includes)
      relation.with_cache.should == [model_one_record_one]
      cache_key = {:class => "LastModCache::Test::ModelOne", :method => :all_with_cache, :updated_at => LastModCache::Test::ModelOne.maximum(:updated_at).to_f, :row_count => 3, :sql => relation.to_sql, :bind_values => []}
      cached = Rails.cache.read(cache_key).first
      if cached.respond_to?(:association)
        cached.association(:widget).loaded?.should == true
        cached.association(:things).loaded?.should == true
        cached.things.first.association(:widget).loaded?.should == true
      else
        cached.widget.loaded?.should == true
        cached.things.loaded?.should == true
      end
    end
  end
  
  context LastModCache::Proxy do
    it "should proxy all methods except __id__" do
      proxy = LastModCache::Proxy.new{ nil }
      proxy.nil?.should == true
      proxy.send(:nil?).should == true
      
      proxy = LastModCache::Proxy.new{ "abc" }
      proxy.nil?.should == false
      proxy.size.should == 3
    end
    
    it "should only evaluate the block once" do
      i = 0
      obj = Object.new
      proxy = LastModCache::Proxy.new{ i += 1; obj }
      proxy.should == obj
      proxy.nil?
      i.should == 1
    end
    
    it "should lazy evaluate the block" do
      proxy = LastModCache::Proxy.new{ raise "never get here" }
    end
    
    it "should handle missing methods" do
      proxy = LastModCache::Proxy.new{ Object.new }
      lambda{ proxy.not_a_method }.should raise_error(NoMethodError)
    end
  end
  
  context "SQL caching" do
    before :each do
      model_one_record_one
    end
    
    it "should cache sql used for finding one record" do
      LastModCache::Test::ModelOne.connection.cache do
        LastModCache::Test::ModelOne.find_by_name_with_cache("one").should == model_one_record_one
        LastModCache::Test::ModelOne.connection.should_not_receive(:select)
        LastModCache::Test::ModelOne.find_by_name_with_cache("one").should == model_one_record_one
      end
    end
    
    it "should cache sql used for finding many record" do
      LastModCache::Test::ModelOne.connection.cache do
        LastModCache::Test::ModelOne.find_all_by_name_with_cache("one").should == [model_one_record_one]
        LastModCache::Test::ModelOne.connection.should_not_receive(:select)
        LastModCache::Test::ModelOne.find_all_by_name_with_cache("one").should == [model_one_record_one]
      end
    end
  end
end
