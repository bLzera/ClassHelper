class AssignmentsController < ApplicationController
  before_action :authenticate_user!

  def sync
    # Épico B-2: busca tarefas no Classroom e faz upsert
    render json: { message: "not_implemented" }, status: :not_implemented
  end

  def update_priority
    # Épico C-1: atualiza prioridade manual
    render json: { message: "not_implemented" }, status: :not_implemented
  end
end
