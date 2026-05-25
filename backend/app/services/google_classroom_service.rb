require "httparty"

class GoogleClassroomService
  COURSES_URL = "https://classroom.googleapis.com/v1/courses".freeze

  class ApiError < StandardError; end

  def initialize(access_token:)
    @access_token = access_token
  end

  def fetch_courses
    response = HTTParty.get(
      COURSES_URL,
      headers: { "Authorization" => "Bearer #{@access_token}" },
      query: { courseStates: "ACTIVE" }
    )

    raise ApiError, "Classroom API error #{response.code}: #{response.body}" unless response.success?

    response.parsed_response.fetch("courses", [])
  end
end
