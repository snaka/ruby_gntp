#!/usr/bin/ruby
#
# Ruby/GNTP example : twitter notifier
#
# Usage: {{{
#     Please type the following command from command line, 
#     and then, this script gets your time-line every 30 seconds.
#
#     > ruby twitter_notifyer.rb
#
#     If you want *STOP* this script, so press Ctrl + 'C'.
#
# Require environment variables:
#   - EDITOR     : For Pit uses this variable to edit account information.
#                   ex) set EDITOR = c:\Progra~1\vim71\vim.exe
#
#   - HTTP_PROXY : If you access the Internet via proxy server, you need
#                  this variable setting.
#                  If variable's value icludes protcol scheme('http://' etc.)
#                  would ignore that.
#                   ex) set HTTP_PROXY = http://proxy.host.name:8080
#                         or
#                       set HTTP_PROXY = proxy.host.name:8080
#
# Web page:
#   http://d.hatena.ne.jp/snaka72/
#   http://sumimasen2.blogspot.com/
#
# License: public domain
# }}}

require 'net/http'

require 'rubygems'
require 'json'
require 'pit'
require 'ruby_gntp'

$tweeted = {}

$growl = GNTP.new
$growl.register({
  :app_name => "Twitter",
  :notifications => [{ :name => "Tweet", :enabled => true },
               	     { :name => "Error", :enabled => true }]
})

def get_timeline

  max_count = 20

  config = Pit.get("twitter", :require => {
    "username" => "your twittername",
    "password" => "your password"
  })

  Net::HTTP.version_1_2
  req = Net::HTTP::Get.new('/statuses/friends_timeline.json')
  req.basic_auth config["username"], config["password"]

  proxy_host, proxy_port = (ENV["HTTP_PROXY"] || '').sub(/http:\/\//, '').split(':')

  Net::HTTP::Proxy(proxy_host, proxy_port).start('twitter.com') {|http|
    res = http.request(req)

    if res.code != '200'
      $growl.notify({
        :name  => "Error",
        :title => "Error occurd",
        :test  => "Can not get messages"
      })
      puts res if $DEBUG
      return
    end

    results = JSON.parser.new(res.body).parse()
    results.reverse!
    results.length.times do |i|
      break if i >= max_count

      id = results[i]["id"]
      next if $tweeted.include?(id)

      puts screen_name  = results[i]["user"]["screen_name"]
      puts text         = results[i]["text"]
      puts icon         = results[i]["user"]["profile_image_url"]

      $growl.notify({
        :name => "Tweet",
        :title =>  screen_name,
        :text => text,
        :icon => icon
      })
      $tweeted[id] = true

      sleep 1
    end
  }
end

# Check timeline evry 30 seconds.
while true do
  get_timeline
  sleep 30
end

# vim: ts=2 sw=2 et fdm=marker
