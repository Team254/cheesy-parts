# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Contains maintenance and deployment configuration.

require "bundler/setup"
require "sequel"

Sequel.extension :migration

namespace :db do
  task :migrate do
    DB = Sequel.mysql2({ :host => "localhost", :user => "root", :database => "cheesy_parts" })
    Sequel::Migrator.run(DB, "db/migrations")
  end
end
