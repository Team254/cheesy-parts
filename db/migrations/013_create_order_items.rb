Sequel.migration do
  change do
    create_table(:order_items) do
      primary_key :id
      Integer :project_id
      Integer :order_id
      Integer :quantity
      String :part_number
      String :description
      Decimal :unit_cost, :size => [10, 2]
      Text :notes
    end
  end
end
