# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a grouping of related parts, such as a certain robot.

class Project < Sequel::Model
  one_to_many :parts
  one_to_many :orders
end
