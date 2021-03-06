$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "fiksu-af/version"

Gem::Specification.new do |s|
 s.name        = 'fiksu-af'
 s.version     = Af::VERSION
 s.license     = 'New BSD License'
 s.date        = '2014-07-10'
 s.summary     = "An application framework for ruby on rails based scripts."
 s.description = "Af groups together gems and provides some glue and helper classes to easily creating applications in a ruby on rails environment."
 s.authors     = ["Keith Gabryelski", "Leonardo Meira"]
 s.email       = ['keith@fiksu.com', 'lmeira@fiksu.com']
 s.files       = `git ls-files`.split("\n")
 s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
 s.require_path = 'lib'
 s.homepage    = 'http://github.com/fiksu/af'
 s.add_dependency 'pg_application_name', '>= 1.0.0'
 s.add_dependency 'pg_advisory_locker', '>= 0.9.0'
 s.add_dependency 'log4r', '1.1.10'
 s.add_dependency "log4r_remote_syslog_outputter", "0.0.1"
 s.add_dependency 'reasonable_log4r', '>= 0.9.0'
 s.add_dependency 'uuid'
 s.add_dependency "rails", '>= 3.0.0'
 s.add_dependency 'rspec-rails', '>=2.12.0'
end
