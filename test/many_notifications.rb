require '../lib/ruby_gntp'

g = GNTP.new("test")

g.register( :notifications => [
    { :name => "notify",  :enabled => true },
    { :name => "warning", :enabled => true },
    { :name => "error",   :enabled => true },
])

g.notify(
  :name => "notify",
  :title => "Test",
  :text  => "hoge fuga"
)

g.notify(
  :name => "warning",
  :title => "warning",
  :text => "Warn!"
)

g.notify(
  :name => "error",
  :title => "error",
  :text => "ERROR"
)


