# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "mta-settings"
  spec.version       = "1.1.3"
  spec.authors       = ["Tim Pope"]
  spec.email         = ["code\x41tp" + 'ope.net']
  spec.summary       = %q{Configure ActionMailer or Mail delivery settings based on the environment}
  spec.description   = <<-TEXT
Configure ActionMailer or Mail delivery settings based on either a singular
MTA_URL environment variable or common conventions for popular off the shelf
SMTP providers.
TEXT
  spec.homepage      = "https://github.com/tpope/#{spec.name}"
  spec.license       = "MIT"

  spec.files = [
    "README.markdown",
    "LICENSE.txt",
    "lib/mta-settings.rb",
    "lib/mta_settings.rb",
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "minitest", "~> 5"
  spec.add_runtime_dependency "activesupport", ">= 3.0.0", "< 8"
end
