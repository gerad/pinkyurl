require 'pinkyurl'

Sinatra::Application.set :raise_errors, true

log = File.new("sinatra.log", "a")
$stdout.reopen(log)
$stderr.reopen(log)

ENV['DISPLAY'] = ':420'

run Sinatra::Application
