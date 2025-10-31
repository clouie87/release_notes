$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "release_notes/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "release_notes"
  s.version     = ReleaseNotes::VERSION
  s.authors     = ["Carol Louie", "Nicholas Jakobsen", "Ryan Wallace"]
  s.email       = ["carol.louie@gmail.com", "nicholas@culturecode.ca", "ryan@culturecode.ca"]
  s.homepage    = "https://github.com/clouie87/release_notes"
  s.summary     = "Compiles changes between deployments to servers and updates release notes."
  s.description = "Release Notes compiles the text from your projects merged pull requests to keep your team informed about which changes have been deployed to which servers."
  s.license     = "MIT"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "activesupport"
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_dependency "octokit", "~> 10"
end
