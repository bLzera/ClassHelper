class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Épico F-1: assignments ordenados por prioridade efetiva
    render json: { message: "not_implemented" }, status: :not_implemented
  end
end
