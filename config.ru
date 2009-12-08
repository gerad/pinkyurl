if ENV['RACK_ENV'] == 'production'
  log = File.new("production.log", "a")
  $stdout.reopen(log)
  $stderr.reopen(log)
end

ENV['DISPLAY'] = ':420'

require 'rack_hoptoad'
use Rack::HoptoadNotifier, '543b8c3a3e3e891231fa9305f034f198'

require 'pinkyurl'
Sinatra::Application.set :raise_errors, true
run Sinatra::Application
