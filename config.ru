require 'rubygems'
require 'sinatra'

Sinatra::Application.set :run, false
Sinatra::Application.set :environment, ENV['RACK_ENV']
Sinatra::Application.set :raise_errors, true

log = File.new("sinatra.log", "a")
$stdout.reopen(log)
$stderr.reopen(log)

require 'pinkyurl'
run Sinatra::Application
