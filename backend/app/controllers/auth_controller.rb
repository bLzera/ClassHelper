class AuthController < ApplicationController
  before_action :authenticate_user!, only: [:me]

  def login
    redirect_to GoogleOauthService.new.authorization_url, allow_other_host: true
  end

  def callback
    return redirect_to_frontend("error=oauth_error") if params[:error].present?

    user = authenticate_with_google(params[:code])
    redirect_to_frontend("token=#{issue_jwt(user)}")
  rescue StandardError => e
    Rails.logger.error("OAuth callback failed: #{e.class}: #{e.message}")
    redirect_to_frontend("error=auth_failed")
  end

  def me
    render json: {
      id: current_user.id,
      email: current_user.email,
      name: current_user.name,
      created_at: current_user.created_at.iso8601
    }
  end

  private

  def authenticate_with_google(code)
    oauth    = GoogleOauthService.new
    tokens   = oauth.exchange_code(code)
    userinfo = oauth.fetch_userinfo(tokens["access_token"])
    upsert_user(userinfo, tokens)
  end

  def upsert_user(userinfo, tokens)
    user = User.find_or_initialize_by(google_id: userinfo["sub"])
    user.assign_attributes(
      email: userinfo["email"],
      name: userinfo["name"],
      google_access_token: tokens["access_token"],
      google_refresh_token: tokens["refresh_token"] || user.google_refresh_token
    )
    user.save!
    user
  end

  def issue_jwt(user)
    JwtService.create_access_token(
      { "user_id" => user.id.to_s },
      ENV.fetch("SECRET_KEY_BASE")
    )
  end

  def redirect_to_frontend(fragment)
    frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    redirect_to "#{frontend_url}/auth/callback##{fragment}", allow_other_host: true
  end
end
