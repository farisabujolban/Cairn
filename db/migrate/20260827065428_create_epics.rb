class CreateEpics < ActiveRecord::Migration[8.1]
  def change
    create_table :epics do |t|
      t.references :project, null: false, foreign_key: true
      # Optional by design: containment (project) and scheduling (milestone) are
      # separate axes, so work can be filed before anyone commits to a date.
      t.references :milestone, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "backlog"
      t.integer :position, null: false

      t.timestamps
    end

    # The backlog tree reads one project's epics in position order, which is
    # this index exactly.
    add_index :epics, [ :project_id, :position ]
  end
end
