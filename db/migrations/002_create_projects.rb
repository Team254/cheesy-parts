Sequel.migration do
  change do
    create_table(:projects) do
      primary_key :id
      String :name, :null => false, :unique => true
      Integer :part_number_prefix, :null => false, :unique => true
    end
  end
end
