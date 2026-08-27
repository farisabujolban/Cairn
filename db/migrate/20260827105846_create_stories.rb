class CreateStories < ActiveRecord::Migration[8.1]
  def change
    create_table :stories do |t|
      t.references :epic, null: false, foreign_key: true
      # Scheduling and assignment are separate axes from containment, so both
      # are optional: work is written down before a date or an owner exists.
      t.references :milestone, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "backlog"
      t.integer :position, null: false

      t.timestamps
    end

    # The backlog tree reads one epic's stories in position order, which is this
    # index exactly.
    add_index :stories, [ :epic_id, :position ]
  end
end
