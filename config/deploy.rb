require 'bundler/capistrano'

set :application, "pinkyurl"
set :scm, "git"
set :repository, "git://github.com/gerad/pinkyurl.git"
set :branch, "nko"
set :deploy_via, :remote_cache

set :user, "app"
set :use_sudo, false

role :app, "173.255.194.119"
role :db, "173.255.194.119", :primary => true

namespace :deploy do
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{current_path}/tmp/restart.txt"
  end
end

namespace :deploy do
  task :finalize_update_more do
    # configs
    run <<-CMD
      ln -fs #{shared_path}/system/aws.yml #{release_path}/config/aws.yml &&
      ln -fs #{shared_path}/system/memcache.yml #{release_path}/config/memcache.yml
    CMD

    # shared cache
    run "ln -s #{shared_path}/system/cache #{release_path}/tmp/cache"
  end
end

after 'deploy:finalize_update', 'deploy:finalize_update_more'
