Sequel.migration do
  change do
    alter_table(:users) do
      add_column :wordpress_user_id, Integer, :unique => true
    end
  end
end
