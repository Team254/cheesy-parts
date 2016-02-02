require "pathological"

require_relative "../../models/user"

Sequel.migration do
  up do
    user = User.new(:email => "deleteme@team254.com", :first_name => "Delete", :last_name => "Me",
                    :permission => "admin", :enabled => 1)
    user.set_password("chezypofs")
    user.save
  end

  down do
    User[:email => "deleteme@team254.com"].delete rescue nil
  end
end
