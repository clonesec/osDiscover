# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)
require 'rake'
require 'rake/dsl_definition'


# cls: the following doesn't work on Heroku:
# cls: fix bug with rails 3.0.7 and rake 0.9.0:
# class Rails::Application
#   include Rake::DSL if defined?(Rake::DSL)
# end

Greenbone::Application.load_tasks
