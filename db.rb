# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Sets up database connection.

DB = Sequel.mysql2({ :host => "localhost", :user => "team254", :password => "skyf1r3",
                     :database => "cheesy_parts" })
