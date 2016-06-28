# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Script for starting/stopping the parts management server.

require "bundler/setup"
require "daemons"
require "pathological"
require "thin"

pwd = Dir.pwd
Daemons.run_proc("parts_server", :monitor => true) do
  Dir.chdir(pwd)  # Fix working directory after daemons sets it to /.
  require "parts_server"

  Thin::Server.start("0.0.0.0", CheesyCommon::Config.port, CheesyParts::Server)
end
