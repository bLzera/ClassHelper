class AddUniqueIndexToCourses < ActiveRecord::Migration[7.2]
  def change
    add_index :courses, %i[user_id google_course_id], unique: true
  end
end
