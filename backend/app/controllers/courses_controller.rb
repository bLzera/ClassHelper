class CoursesController < ApplicationController
  before_action :authenticate_user!

  def sync
    # Épico B-1: busca cursos no Classroom e faz upsert
    render json: { message: "not_implemented" }, status: :not_implemented
  end
end
