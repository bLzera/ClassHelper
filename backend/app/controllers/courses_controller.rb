class CoursesController < ApplicationController
  before_action :authenticate_user!

  PENDING_COUNT_SQL = "COUNT(assignments.id) FILTER " \
                      "(WHERE assignments.state = 'CREATED') AS pending_count".freeze
  NEXT_DUE_DATE_SQL = "MIN(assignments.due_date) FILTER " \
                      "(WHERE assignments.state = 'CREATED' " \
                      "AND assignments.due_date IS NOT NULL) AS next_due_date".freeze
  private_constant :PENDING_COUNT_SQL, :NEXT_DUE_DATE_SQL

  def index
    render json: { courses: courses_with_aggregates.map { |course| serialize_course(course) } }, status: :ok
  end

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

  def courses_with_aggregates
    current_user.courses
                .left_joins(:assignments)
                .select("courses.id", "courses.google_course_id", "courses.name",
                        "courses.section", PENDING_COUNT_SQL, NEXT_DUE_DATE_SQL)
                .group("courses.id")
                .order("courses.name ASC")
  end

  def serialize_course(course)
    {
      id: course.id,
      google_course_id: course.google_course_id,
      name: course.name,
      section: course.section,
      pending_count: course.pending_count.to_i,
      next_due_date: course.next_due_date&.iso8601
    }
  end

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
