Sequel.migration do
  change do
    alter_table(:orders) do
      add_column :reimbursed, Integer, :null => false
    end
  end
end
