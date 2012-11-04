# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# The main class of the parts management web server.

require "pathological"
require "sinatra/base"

module CheesyParts
  class Server < Sinatra::Base
    get "/" do
      "This page intentionally left blank."
    end
  end
end
