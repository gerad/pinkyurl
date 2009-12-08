load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

set :application, "pinkyurl"
set :scm, "git"
set :repository, "git://github.com/gerad/pinkyurl.git"
set :deploy_via, :remote_cache

set :user, "app"
set :use_sudo, false

role :app, "pinkyurl.com"

namespace :deploy do
  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end

  task :finalize_update, :roles => :app do
    # configs
    run "ln -fs #{shared_path}/system/aws.yml #{release_path}/config/aws.yml"
    run "ln -fs #{shared_path}/system/memcache.yml #{release_path}/config/memcache.yml"

    # shared cache
    run "ln -s #{shared_path}/system/cache #{release_path}/public/cache"
  end
end
