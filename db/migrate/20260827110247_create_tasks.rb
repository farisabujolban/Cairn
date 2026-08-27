class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      # NOT NULL is the no-subtasks rule (§6) made physical: a task with no
      # story cannot be written, so there is no row for nesting to hang off.
      # There is deliberately no parent_id here, and never will be.
      t.references :story, null: false, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :status, null: false, default: "backlog"
      t.integer :position, null: false

      t.timestamps
    end

    # The backlog tree reads one story's tasks in position order, which is this
    # index exactly.
    add_index :tasks, [ :story_id, :position ]
  end
end
