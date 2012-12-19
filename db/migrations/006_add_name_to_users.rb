Sequel.migration do
  change do
    alter_table(:users) do
      add_column :first_name, String, :null => false
      add_column :last_name, String, :null => false
    end
  end
end
