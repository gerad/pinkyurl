require 'pinkyurl'
require 'rack_hoptoad'

Sinatra::Application.set :raise_errors, true
log = File.new("sinatra.log", "a")
$stdout.reopen(log)
$stderr.reopen(log)

ENV['DISPLAY'] = ':420'

use Rack::HoptoadNotifier, '543b8c3a3e3e891231fa9305f034f198'

run Sinatra::Application
