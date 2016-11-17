Sequel.migration do
  change do
    alter_table(:projects) do
      add_column :onshape_top_document, String
      add_column :onshape_top_element, String
    end
    alter_table(:parts) do
      add_column :onshape_document, String
      add_column :onshape_element, String
      add_column :onshape_workspace, String
      add_column :onshape_part, String
      add_column :onshape_microversion, String
      add_column :onshape_qty, Integer
    end
  end
end
