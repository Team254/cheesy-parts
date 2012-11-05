Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email, :null => false, :unique => true
      String :password, :null => false
      String :salt, :null => false
      String :permission, :null => false
    end
  end
end
