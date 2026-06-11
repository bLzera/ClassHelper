require "jwt"

module JwtService
  ALGORITHM   = "HS256".freeze
  EXPIRY_SECS = 30 * 60

  module_function

  def create_access_token(data, secret_key)
    payload = data.dup
    payload["exp"] = Time.now.utc.to_i + EXPIRY_SECS
    JWT.encode(payload, secret_key, ALGORITHM)
  end

  def decode_access_token(token, secret_key)
    decoded, _header = JWT.decode(token, secret_key, true, algorithms: [ALGORITHM])
    decoded
  end
end
