Sequel.migration do
  up do
    alter_table(:parts) do
      drop_constraint :part_number, :type => :unique
      add_unique_constraint [:project_id, :part_number], :name => :project_id_and_part_number
    end
  end
  down do
    alter_table(:parts) do
      drop_constraint :project_id_and_part_number, :type => :unique
      add_unique_constraint :part_number
    end
  end
end
