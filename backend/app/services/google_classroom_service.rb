require "httparty"

class GoogleClassroomService
  COURSES_URL     = "https://classroom.googleapis.com/v1/courses".freeze
  PAGE_SIZE       = 100
  REQUEST_TIMEOUT = 10

  class ApiError < StandardError; end
  class TokenExpiredError < StandardError; end

  def initialize(user:, oauth_service: GoogleOauthService.new)
    @user          = user
    @oauth_service = oauth_service
  end

  def fetch_courses
    fetch_all_pages(COURSES_URL, "courses", query: { courseStates: "ACTIVE" })
  end

  def fetch_course_work(course_id)
    fetch_all_pages("#{COURSES_URL}/#{course_id}/courseWork", "courseWork")
  end

  private

  # A Classroom API pagina as listagens: cada resposta traz até `pageSize` itens
  # e, havendo mais, um `nextPageToken` a ser reenviado como `pageToken`.
  def fetch_all_pages(url, items_key, query: {})
    items      = []
    page_token = nil

    loop do
      body = fetch_page(url, query, page_token)
      items.concat(body.fetch(items_key, []))
      page_token = body["nextPageToken"]
      break if page_token.nil?
    end

    items
  end

  def fetch_page(url, query, page_token)
    response = with_token_refresh do |access_token|
      HTTParty.get(
        url,
        headers: { "Authorization" => "Bearer #{access_token}" },
        query: query.merge(pageSize: PAGE_SIZE, pageToken: page_token).compact,
        timeout: REQUEST_TIMEOUT
      )
    end

    response.parsed_response
  end

  # Yields the current access_token to the block (which performs the HTTP call).
  # On a 401, attempts a single token refresh and retries the call once.
  def with_token_refresh
    response = yield(@user.google_access_token)
    return response if response.success?

    if response.code == 401
      refresh_access_token!
      response = yield(@user.google_access_token)
      return response if response.success?
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
