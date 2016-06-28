# Copyright 2013 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Sets up database connection.

require "cheesy-common"

DB = Sequel.mysql2({ :host => CheesyCommon::Config.db_host, :user => CheesyCommon::Config.db_user,
	:password => CheesyCommon::Config.db_password, :database => CheesyCommon::Config.db_database })
