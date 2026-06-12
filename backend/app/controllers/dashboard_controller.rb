class DashboardController < ApplicationController
  before_action :authenticate_user!

  ASSIGNMENT_FIELDS = %i[id title description due_date state
                         manual_priority auto_priority course_id alternate_link].freeze
  private_constant :ASSIGNMENT_FIELDS

  def index
    assignments = current_user.assignments.by_completed(completed_param?)

    render json: { assignments: assignments.as_json(only: ASSIGNMENT_FIELDS) }, status: :ok
  end

  private

  def completed_param?
    ActiveModel::Type::Boolean.new.cast(params[:completed]) || false
  end
end
