Sequel.migration do
  change do
    alter_table(:parts) do
      add_column :status, String, :null => false
    end
  end
end
