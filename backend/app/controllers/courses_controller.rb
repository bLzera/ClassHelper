class CoursesController < ApplicationController
  before_action :authenticate_user!

  def sync
    service = GoogleClassroomService.new(user: current_user)
    courses = upsert_courses(service.fetch_courses)
    render json: { synced: courses.size, courses: courses.as_json(only: %i[id google_course_id name section]) }
  rescue GoogleClassroomService::TokenExpiredError => e
    render json: { error: "token_expired", message: e.message }, status: :unauthorized
  rescue GoogleClassroomService::ApiError => e
    render json: { error: "classroom_api_error", message: e.message }, status: :bad_gateway
  end

  private

  def upsert_courses(google_courses)
    ActiveRecord::Base.transaction do
      google_courses.map do |gc|
        course = Course.find_or_initialize_by(user: current_user, google_course_id: gc["id"])
        course.update!(name: gc["name"], section: gc["section"])
        course
      end
    end
  end
end
