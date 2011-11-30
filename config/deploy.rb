require "bundler/capistrano"
#load "deploy/assets"

set :application, "osDiscover"
set :location, "38.123.140.55"
set :repository, "file:///Code/repositories/osdiscover.git" #git clone ssh://osdiscover@38.123.140.55/Code/repositories/osdiscover.git
set :local_repository, "file://."


set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, location                          # Your HTTP server, Apache/etc
role :app, location                          # This may be the same as your `Web` server
role :db,  location, :primary => true # This is where Rails migrations will run

set :user, "osdiscover"
set :use_sudo, false
set :deploy_to, "/Code/Ruby/#{application}"

set :keep_releases, 5
after "deploy:update", "deploy:cleanup" 
# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path}; bundle exec rake db:schema:load"
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
    
  end
end