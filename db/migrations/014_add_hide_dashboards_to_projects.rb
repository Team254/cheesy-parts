Sequel.migration do
  change do
    alter_table(:projects) do
      add_column :hide_dashboards, Integer, :null => false
    end
  end
end
