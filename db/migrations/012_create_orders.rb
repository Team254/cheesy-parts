Sequel.migration do
  change do
    create_table(:orders) do
      primary_key :id
      Integer :project_id, :null => false
      String :vendor_name
      String :status, :null => false
      DateTime :ordered_at
      String :paid_for_by
      Decimal :tax_cost, :size => [10, 2]
      Decimal :shipping_cost, :size => [10, 2]
      Text :notes
    end
  end
end
