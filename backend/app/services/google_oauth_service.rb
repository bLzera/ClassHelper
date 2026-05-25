require "httparty"

class GoogleOauthService
  AUTH_BASE_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  TOKEN_URL     = "https://oauth2.googleapis.com/token".freeze
  USERINFO_URL  = "https://www.googleapis.com/oauth2/v3/userinfo".freeze

  class RefreshError < StandardError; end

  SCOPES = [
    "openid",
    "email",
    "profile",
    "https://www.googleapis.com/auth/classroom.courses.readonly",
    "https://www.googleapis.com/auth/classroom.coursework.me.readonly"
  ].join(" ")

  def initialize(
    client_id:     ENV.fetch("GOOGLE_CLIENT_ID"),
    client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
    redirect_uri:  ENV.fetch("GOOGLE_REDIRECT_URI", "http://localhost:3000/auth/callback")
  )
    @client_id     = client_id
    @client_secret = client_secret
    @redirect_uri  = redirect_uri
  end

  def authorization_url
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      response_type: "code",
      scope: SCOPES,
      access_type: "offline",
      prompt: "consent"
    }
    "#{AUTH_BASE_URL}?#{URI.encode_www_form(params)}"
  end

  def exchange_code(code)
    response = HTTParty.post(TOKEN_URL, body: {
                               code: code,
                               client_id: @client_id,
                               client_secret: @client_secret,
                               redirect_uri: @redirect_uri,
                               grant_type: "authorization_code"
                             })
    raise "Google token exchange failed: #{response.body}" unless response.success?

    response.parsed_response
  end

  def refresh_access_token(refresh_token)
    response = HTTParty.post(TOKEN_URL, body: {
                               client_id: @client_id,
                               client_secret: @client_secret,
                               refresh_token: refresh_token,
                               grant_type: "refresh_token"
                             })
    raise RefreshError, "Google token refresh failed: #{response.body}" unless response.success?

    response.parsed_response
  end

  def fetch_userinfo(access_token)
    response = HTTParty.get(USERINFO_URL,
                            headers: { "Authorization" => "Bearer #{access_token}" })
    raise "Google userinfo fetch failed: #{response.body}" unless response.success?

    response.parsed_response
  end
end
