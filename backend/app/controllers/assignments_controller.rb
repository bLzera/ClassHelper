class AssignmentsController < ApplicationController
  before_action :authenticate_user!

  def sync
    service = GoogleClassroomService.new(user: current_user)
    synced = upsert_assignments(service)
    render json: { synced: synced }, status: :ok
  rescue GoogleClassroomService::TokenExpiredError => e
    render json: { error: "token_expired", message: e.message }, status: :unauthorized
  rescue GoogleClassroomService::ApiError => e
    render json: { error: "classroom_api_error", message: e.message }, status: :bad_gateway
  end

  def update_priority
    assignment = Assignment.find_by(id: params[:id], user: current_user)
    return render json: { error: "not_found" }, status: :not_found if assignment.nil?

    assignment.update!(manual_priority: params[:manual_priority])
    render json: assignment.as_json(only: %i[id title manual_priority auto_priority due_date state course_id])
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RangeError, ActiveModel::RangeError
    render json: { error: "invalid_priority" }, status: :unprocessable_content
  end

  private

  def upsert_assignments(service)
    current_user.courses.find_each.sum do |course|
      # A busca HTTP fica fora da transação: um refresh malsucedido limpa os
      # tokens do usuário e essa limpeza não pode ser desfeita por rollback.
      course_work = service.fetch_course_work(course.google_course_id)
      upsert_course_work(course, course_work)

      # O estado de entrega do aluno vive em studentSubmissions — buscado fora
      # da transação acima e aplicado por cima do estado de publicação do prof.
      submissions = service.fetch_submissions(course.google_course_id)
      apply_submission_states(course, submissions)

      course_work.size
    end
  end

  def upsert_course_work(course, course_work)
    ActiveRecord::Base.transaction do
      course_work.each { |cw| build_assignment(course, cw) }
    end
  end

  # Casa cada submissão ao assignment pelo courseWorkId (== google_assignment_id)
  # e grava o estado de entrega real. Tarefa sem submissão permanece "CREATED".
  def apply_submission_states(course, submissions)
    return if submissions.empty?

    ActiveRecord::Base.transaction do
      submissions.each { |submission| apply_submission_state(course, submission) }
    end
  end

  def apply_submission_state(course, submission)
    assignment = course.assignments.find_by(
      google_assignment_id: submission["courseWorkId"],
      user: current_user
    )
    return if assignment.nil?

    assignment.update!(state: map_submission_state(submission["state"]))
  end

  def map_submission_state(state)
    Assignment::VALID_STATES.include?(state) ? state : "CREATED"
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
      auto_priority: Assignment.calculate_auto_priority(due_date),
      alternate_link: course_work["alternateLink"]
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
