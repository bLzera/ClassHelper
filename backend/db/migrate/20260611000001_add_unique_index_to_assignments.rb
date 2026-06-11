class AddUniqueIndexToAssignments < ActiveRecord::Migration[7.2]
  def change
    add_index :assignments, %i[user_id course_id google_assignment_id],
              unique: true, name: "index_assignments_on_user_course_and_google_assignment_id"

    # Índices de coluna única cobertos pelo prefixo dos índices compostos.
    remove_index :assignments, :user_id
    remove_index :courses, :user_id
  end
end
