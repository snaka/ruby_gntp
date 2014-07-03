$:.push File.expand_path("../lib", __FILE__)
require 'ruby_gntp'

Gem::Specification.new do |s|
  s.name = GNTP::RUBY_GNTP_NAME
  s.version = GNTP::RUBY_GNTP_VERSION
  s.summary = "Ruby library for GNTP(Growl Notification Transport Protocol) client"
  s.authors = ["snaka", "David Hayward (spidah)"]
  s.email = ["snaka.gml@gmail.com", "spidahman@gmail.com"]
  s.homepage = "http://snaka.github.com/ruby_gntp/"
  s.files = [
    "lib/ruby_gntp.rb",
    "example/twitter_notifier.rb",
    "example/gntp-notify",
    "test/ruby_gntp_spec.rb",
    "test/ruby_gntp_spec_helper.rb",
    "README",
    "TODO",
    "ChangeLog"
  ]
  s.has_rdoc = false
end
