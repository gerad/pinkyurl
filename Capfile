load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

set :application, "pinkyurl"
set :scm, "git"
set :repository, "git://github.com/visnup/pinkyurl.git"
set :branch, "fortnight"
set :deploy_via, :remote_cache

set :user, "app"
set :use_sudo, false

role :app, "pinkyurl.com"

namespace :deploy do
  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end

  task :finalize_update, :roles => :app do
    run "ln -fs #{shared_path}/system/aws.yml #{current_path}/config/aws.yml"
    run "ln -fs #{shared_path}/system/memcache.yml #{current_path}/config/memcache.yml"
  end
end
