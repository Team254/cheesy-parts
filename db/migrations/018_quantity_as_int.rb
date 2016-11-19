Sequel.migration do
  change do
    alter_table(:parts) do
      drop_column :onshape_qty
      drop_column :quantity
      add_column :quantity, Integer
    end
  end
end
