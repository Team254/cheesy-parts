# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Script for starting/stopping the parts management server.

require "daemons"
require "pathological"
require "thin"

Daemons.run_proc("parts_server", :monitor => true) do
  require "parts_server"

  Thin::Server.start("0.0.0.0", PORT, CheesyParts::Server)
end
