class CreateMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :milestones do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :due_on
      t.string :state, null: false, default: "open"

      t.timestamps
    end

    # The milestone list is read per project in ship order, which is this index
    # exactly. Undated milestones sort last in the scope, not in the index.
    add_index :milestones, [ :project_id, :due_on ]
  end
end
