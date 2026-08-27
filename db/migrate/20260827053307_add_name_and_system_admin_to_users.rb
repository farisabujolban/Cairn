class AddNameAndSystemAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string, null: false
    add_column :users, :system_admin, :boolean, null: false, default: false
  end
end
