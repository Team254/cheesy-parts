# Copyright 2013 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a line item in an order from a vendor.

class OrderItem < Sequel::Model
  many_to_one :order
  many_to_one :project

  def total_cost
    unit_cost * quantity
  end
end
