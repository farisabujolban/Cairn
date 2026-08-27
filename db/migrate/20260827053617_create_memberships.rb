class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end

    # One membership per user per project: the pair is the identity of the grant,
    # so the database refuses a second row rather than trusting the validation.
    add_index :memberships, [ :user_id, :project_id ], unique: true
  end
end
