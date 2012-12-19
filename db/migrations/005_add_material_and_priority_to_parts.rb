Sequel.migration do
  change do
    alter_table(:parts) do
      add_column :source_material, String, :null => false
      add_column :have_material, Integer, :null => false
      add_column :quantity, String, :null => false
      add_column :cut_length, String, :null => false
      add_column :priority, Integer, :null => false
      add_column :drawing_created, Integer, :null => false
    end
  end
end
