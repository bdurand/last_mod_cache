require 'rubygems'
require 'rubygems/package_task'
require 'rake'

desc 'Default: run unit tests.'
task :default => :test

desc 'RVM likes to call it tests'
task :tests => :test

begin
  require 'rspec'
  require 'rspec/core/rake_task'
  desc 'Run the unit tests'
  RSpec::Core::RakeTask.new(:test)
rescue LoadError
  task :test do
    STDERR.puts "You must have rspec 2.0 installed to run the tests"
  end
end

spec_file = File.expand_path('../last_mod_cache.gemspec', __FILE__)
if File.exist?(spec_file)
  spec = eval(File.read(spec_file))

  Gem::PackageTask.new(spec) do |p|
    p.gem_spec = spec
  end
end
