Sequel.migration do
  change do
    alter_table(:users) do
      add_column :enabled, Integer, :null => false
    end
  end
end
