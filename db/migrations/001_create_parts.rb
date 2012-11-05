Sequel.migration do
  change do
    create_table(:parts) do
      primary_key :id
      Integer :part_number, :null => false, :unique => true
      Integer :project_id, :null => false
      String :type, :null => false
      String :name, :null => false
      Integer :parent_part_id
      Text :notes
    end
  end
end
