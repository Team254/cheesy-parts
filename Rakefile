# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Contains maintenance and deployment configuration.

require "bundler/setup"
require "pathological"
require "sequel"

Sequel.extension :migration

# Task for executing any pending database schema changes.
namespace :db do
  task :migrate do
    require_relative "db"
    Sequel::Migrator.run(DB, "db/migrations")
  end
end
