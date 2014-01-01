# Copyright 2013 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents an order from a vendor consisting of multiple items.

class Order < Sequel::Model
  one_to_many :order_items
  many_to_one :project

  # The list of possible order statuses. Key: string stored in database, value: what is displayed to the user.
  STATUS_MAP = {
    "open" => "Open",
    "ordered" => "Ordered",
    "received" => "Received"
  }
end
