Gem::Specification.new do |s|
  s.name = 'last_mod_cache'
  s.version = File.read(File.expand_path("../VERSION", __FILE__)).strip
  s.summary = "An extension for ActiveRecord models that adds a caching layer for models that include an updated at column."
  s.description = "An extension for ActiveRecord models that adds a caching layer for models that include an updated at column."

  s.authors = ['Brian Durand']
  s.email = ['bdurand@embellishedvisions.com']
  s.homepage = "http://github.com/bdurand/last_mod_cache"

  s.files = ['README.rdoc', 'VERSION', 'Rakefile', 'MIT_LICENSE'] +  Dir.glob('lib/**/*'), Dir.glob('spec/**/*')
  s.require_path = 'lib'
  
  s.has_rdoc = true
  s.rdoc_options = ["--charset=UTF-8", "--main", "README.rdoc"]
  s.extra_rdoc_files = ["README.rdoc"]
  
  s.add_dependency "activerecord", ">=3.0.0"
  s.add_development_dependency "rspec", ">2.0.0"
  s.add_development_dependency "sqlite3"
end
