class AssignmentsController < ApplicationController
  before_action :authenticate_user!

  def sync
    service = GoogleClassroomService.new(access_token: current_user.google_access_token)
    synced = upsert_assignments(service)
    render json: { synced: synced }, status: :ok
  rescue GoogleClassroomService::ApiError => e
    render json: { error: "classroom_api_error", message: e.message }, status: :bad_gateway
  end

  def update_priority
    assignment = Assignment.find_by(id: params[:id], user: current_user)
    return render json: { error: "not_found" }, status: :not_found if assignment.nil?

    assignment.update!(manual_priority: params[:manual_priority])
    render json: assignment.as_json(only: %i[id title manual_priority auto_priority due_date state course_id])
  end

  private

  def upsert_assignments(service)
    count = 0
    ActiveRecord::Base.transaction do
      current_user.courses.find_each do |course|
        service.fetch_course_work(course.google_course_id).each do |cw|
          build_assignment(course, cw)
          count += 1
        end
      end
    end
    count
  end

  def build_assignment(course, course_work)
    assignment = Assignment.find_or_initialize_by(
      google_assignment_id: course_work["id"],
      user: current_user,
      course: course
    )
    assignment.update!(assignment_attributes(course_work))
  end

  def assignment_attributes(course_work)
    due_date = parse_due_date(course_work["dueDate"])
    {
      title: course_work["title"],
      description: course_work["description"],
      due_date: due_date,
      state: map_state(course_work["state"]),
      auto_priority: Assignment.calculate_auto_priority(due_date)
    }
  end

  def parse_due_date(due_date)
    return nil if due_date.nil?

    Date.new(due_date["year"], due_date["month"], due_date["day"])
  end

  def map_state(state)
    return "CREATED" if state == "PUBLISHED"

    Assignment::VALID_STATES.include?(state) ? state : "CREATED"
  end
end
