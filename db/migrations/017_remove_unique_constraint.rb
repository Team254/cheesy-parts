Sequel.migration do
  up do
    alter_table(:parts) do
      drop_constraint :project_id_and_part_number, :type => :unique
      set_column_allow_null :part_number
      set_column_default :part_number, nil
    end
  end
  down do
    alter_table(:parts) do
      add_unique_constraint [:project_id, :part_number], :name => :project_id_and_part_number
    end
  end
end
