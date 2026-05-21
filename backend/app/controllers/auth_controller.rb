class AuthController < ApplicationController
  before_action :authenticate_user!, only: [:me]

  def login
    redirect_to GoogleOauthService.new.authorization_url, allow_other_host: true
  end

  def callback
    if params[:error].present?
      return render json: { error: "oauth_error", message: params[:error] },
                    status: :bad_request
    end

    oauth = GoogleOauthService.new
    tokens   = oauth.exchange_code(params[:code])
    userinfo = oauth.fetch_userinfo(tokens["access_token"])

    user = User.find_or_initialize_by(google_id: userinfo["sub"])
    user.assign_attributes(
      email:                userinfo["email"],
      name:                 userinfo["name"],
      google_access_token:  tokens["access_token"],
      google_refresh_token: tokens["refresh_token"] || user.google_refresh_token
    )
    user.save!

    jwt = JwtService.create_access_token(
      { "user_id" => user.id.to_s },
      ENV.fetch("SECRET_KEY_BASE")
    )

    render json: { access_token: jwt, token_type: "bearer" }
  rescue StandardError => e
    render json: { error: "auth_failed", message: e.message }, status: :internal_server_error
  end

  def me
    render json: {
      id:         current_user.id,
      email:      current_user.email,
      name:       current_user.name,
      created_at: current_user.created_at.iso8601
    }
  end
end
