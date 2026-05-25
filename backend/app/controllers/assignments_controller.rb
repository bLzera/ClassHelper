class AssignmentsController < ApplicationController
  before_action :authenticate_user!

  def sync
    # Épico B-2: busca tarefas no Classroom e faz upsert
    render json: { message: "not_implemented" }, status: :not_implemented
  end

  def update_priority
    assignment = Assignment.find_by(id: params[:id], user: current_user)
    return render json: { error: "not_found" }, status: :not_found if assignment.nil?

    assignment.update!(manual_priority: params[:manual_priority])
    render json: assignment.as_json(only: %i[id title manual_priority auto_priority due_date state course_id])
  end
end
