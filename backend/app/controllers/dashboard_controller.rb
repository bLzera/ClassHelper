class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    assignments = current_user.assignments
                              .where(state: "CREATED")
                              .order(Arel.sql("COALESCE(manual_priority, auto_priority) ASC NULLS LAST"))

    render json: {
      assignments: assignments.as_json(
        only: %i[id title description due_date state manual_priority auto_priority course_id]
      )
    }, status: :ok
  end
end
