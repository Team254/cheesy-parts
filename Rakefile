# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Contains maintenance and deployment configuration.

require "bundler/setup"
require "fezzik"
require "pathological"
require "sequel"

Sequel.extension :migration

namespace :db do
  task :migrate do
    require "db"
    Sequel::Migrator.run(DB, "db/migrations")
  end
end

Fezzik.init(:tasks => "config/tasks")

set :app, "cheesy-parts"
set :deploy_to, "/opt/team254/#{app}"
set :release_path, "#{deploy_to}/releases/#{Time.now.strftime("%Y%m%d%H%M")}"
set :local_path, Dir.pwd
set :user, "ubuntu"

Fezzik.destination :prod do
  set :domain, "#{user}@parts.team254.com"
end
