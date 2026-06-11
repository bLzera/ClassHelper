class CreateInitialSchema < ActiveRecord::Migration[7.2]
  def up
    enable_extension "pgcrypto"

    create_table :users, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string :google_id,            limit: 255,  null: false
      t.string :email,                limit: 255,  null: false
      t.string :name,                 limit: 255,  null: false
      t.string :google_access_token,  limit: 2048
      t.string :google_refresh_token, limit: 2048
      t.timestamps null: false
    end
    add_index :users, :google_id, unique: true
    add_index :users, :email,     unique: true

    create_table :courses, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :google_course_id, limit: 255, null: false
      t.string :name,             limit: 500, null: false
      t.string :section,          limit: 255
      t.timestamps null: false
    end

    create_table :assignments, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :course, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :user,   null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string  :google_assignment_id, limit: 255, null: false
      t.string  :title,                limit: 500, null: false
      t.text    :description
      t.datetime :due_date
      t.string  :state, limit: 50, null: false, default: "CREATED"
      t.integer :manual_priority
      t.integer :auto_priority
      t.timestamps null: false
    end
  end

  def down
    drop_table :assignments
    drop_table :courses
    drop_table :users
    disable_extension "pgcrypto"
  end
end
