Gem::Specification.new do |spec|
  spec.name        = "my_engine"
  spec.version     = "0.1.0"
  spec.authors     = ["Chris Salzberg"]
  spec.email       = ["email"]
  spec.homepage    = "https://github.com/shioyama/rails_on_im"
  spec.summary     = "summary"
  spec.description = "description"
  
  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/shioyama/rails_on_im"
  #spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.4.2"
end
