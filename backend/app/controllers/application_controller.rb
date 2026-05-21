class ApplicationController < ActionController::API
  private

  def authenticate_user!
    token = extract_bearer_token
    return render_unauthorized unless token

    payload = JwtService.decode_access_token(token, ENV.fetch("SECRET_KEY_BASE"))
    @current_user = User.find(payload["user_id"])
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
    render_unauthorized
  end

  def current_user
    @current_user
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last if header&.start_with?("Bearer ")
  end

  def render_unauthorized
    render json: { error: "unauthorized" }, status: :unauthorized
  end
end
