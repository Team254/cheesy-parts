# Copyright 2013 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Sets up database connection.

require_relative "config"

DB = Sequel.mysql2({ :host => Config.db_host, :user => Config.db_user, :password => Config.db_password,
	:database => Config.db_database })
