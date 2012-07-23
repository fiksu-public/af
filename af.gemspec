$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "af/version"

Gem::Specification.new do |s|
 s.name        = 'af'
 s.version     = Af::VERSION
 s.license     = 'New BSD License'
 s.date        = '2012-05-13'
 s.summary     = "An application framework for ruby on rails based scripts."
 s.description = "Af groups together gems and provides some glue and helper classes to easily creating applications in a ruby on rails environment."
 s.authors     = ["Keith Gabryelski"]
 s.email       = 'keith@fiksu.com'
 s.executables = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
 s.files       = `git ls-files`.split("\n")
 s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
 s.require_path = 'lib'
 s.homepage    = 'http://github.com/fiksu/af'
 s.add_dependency 'log4r', '1.1.10'
 s.add_dependency 'daemons', '1.1.8'
 s.add_dependency 'uuid', '2.3.4'
 s.add_dependency "rails", '>= 3.0.0'
 s.add_dependency 'rspec-rails', '2.8.1'
end
