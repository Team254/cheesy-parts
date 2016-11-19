Sequel.migration do
  change do
    alter_table(:parts) do
      add_column :onshape_mass, "FLOAT"
    end
  end
end
