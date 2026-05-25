require "httparty"

class GoogleClassroomService
  COURSES_URL = "https://classroom.googleapis.com/v1/courses".freeze

  class ApiError < StandardError; end
  class TokenExpiredError < StandardError; end

  def initialize(user:, oauth_service: GoogleOauthService.new)
    @user          = user
    @oauth_service = oauth_service
  end

  def fetch_courses
    response = with_token_refresh do |access_token|
      HTTParty.get(
        COURSES_URL,
        headers: { "Authorization" => "Bearer #{access_token}" },
        query: { courseStates: "ACTIVE" }
      )
    end

    response.parsed_response.fetch("courses", [])
  end

  def fetch_course_work(course_id)
    response = with_token_refresh do |access_token|
      HTTParty.get(
        "https://classroom.googleapis.com/v1/courses/#{course_id}/courseWork",
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
    end

    response.parsed_response.fetch("courseWork", [])
  end

  private

  # Yields the current access_token to the block (which performs the HTTP call).
  # On a 401, attempts a single token refresh and retries the call once.
  def with_token_refresh
    response = yield(@user.google_access_token)
    return response if response.success?

    if response.code == 401
      refresh_access_token!
      response = yield(@user.google_access_token)
      return response if response.success?

      raise_for_response(response)
    end

    raise_for_response(response)
  end

  def refresh_access_token!
    raise_token_expired if @user.google_refresh_token.blank?

    tokens = @oauth_service.refresh_access_token(@user.google_refresh_token)
    @user.update!(google_access_token: tokens["access_token"])
  rescue GoogleOauthService::RefreshError
    @user.update!(google_access_token: nil, google_refresh_token: nil)
    raise_token_expired
  end

  def raise_for_response(response)
    raise ApiError, "Classroom API error #{response.code}: #{response.body}"
  end

  def raise_token_expired
    raise TokenExpiredError, "Re-autenticação necessária"
  end
end
