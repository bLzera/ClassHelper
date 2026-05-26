require "rails_helper"

RSpec.describe "Auth", type: :request do
  let(:secret)       { "test-secret-key" }
  let(:frontend_url) { "http://localhost:5173" }

  let(:env_keys) do
    %w[
      SECRET_KEY_BASE
      FRONTEND_URL
      GOOGLE_CLIENT_ID
      GOOGLE_CLIENT_SECRET
      GOOGLE_REDIRECT_URI
    ]
  end

  around do |example|
    original_env = env_keys.index_with { |key| ENV.fetch(key, nil) }

    ENV["SECRET_KEY_BASE"]      = secret
    ENV["FRONTEND_URL"]         = frontend_url
    ENV["GOOGLE_CLIENT_ID"]     = "client-id"
    ENV["GOOGLE_CLIENT_SECRET"] = "client-secret"
    ENV["GOOGLE_REDIRECT_URI"]  = "http://localhost:3000/auth/callback"

    example.run

    original_env.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  describe "GET /auth/callback" do
    def stub_token_exchange(refresh_token: "refresh-from-google")
      body = { access_token: "google-access-token", expires_in: 3599 }
      body[:refresh_token] = refresh_token unless refresh_token.nil?

      stub_request(:post, "https://oauth2.googleapis.com/token")
        .with(body: hash_including(grant_type: "authorization_code", code: "valid-code"))
        .to_return(status: 200, body: body.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    def stub_userinfo(sub: "google-sub-123", email: "alice@example.com", name: "Alice")
      stub_request(:get, "https://www.googleapis.com/oauth2/v3/userinfo")
        .with(headers: { "Authorization" => "Bearer google-access-token" })
        .to_return(status: 200,
                   body: { sub: sub, email: email, name: name }.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    context "com code válido" do
      before do
        stub_token_exchange
        stub_userinfo
      end

      it "redireciona 302 para o frontend com o token no fragment" do
        get "/auth/callback", params: { code: "valid-code" }

        expect(response).to have_http_status(:found)
        user = User.find_by(google_id: "google-sub-123")
        expect(response.location).to eq("#{frontend_url}/auth/callback#token=#{extract_token}")

        decoded = JwtService.decode_access_token(extract_token, secret)
        expect(decoded["user_id"]).to eq(user.id.to_s)
      end

      it "não vaza o token na query string (sempre depois do #)" do
        get "/auth/callback", params: { code: "valid-code" }

        uri = URI.parse(response.location)
        expect(uri.query).to be_nil
        expect(uri.fragment).to start_with("token=")
      end
    end

    context "upsert do usuário" do
      before do
        stub_token_exchange
        stub_userinfo
      end

      it "cria o User quando o google_id é novo" do
        expect { get "/auth/callback", params: { code: "valid-code" } }
          .to change(User, :count).by(1)
      end

      it "atualiza o User existente sem duplicar", :aggregate_failures do
        existing = create(:user, google_id: "google-sub-123",
                                 email: "old@example.com", name: "Old Name",
                                 google_access_token: "old-access-token")

        expect { get "/auth/callback", params: { code: "valid-code" } }
          .not_to change(User, :count)

        existing.reload
        expect(existing.email).to eq("alice@example.com")
        expect(existing.name).to eq("Alice")
        expect(existing.google_access_token).to eq("google-access-token")
      end
    end

    context "quando o Google não reenvia refresh_token" do
      before do
        stub_token_exchange(refresh_token: nil)
        stub_userinfo
      end

      it "preserva o refresh_token existente do usuário" do
        create(:user, google_id: "google-sub-123",
                      google_refresh_token: "previously-stored-refresh")

        get "/auth/callback", params: { code: "valid-code" }

        expect(User.find_by(google_id: "google-sub-123").google_refresh_token)
          .to eq("previously-stored-refresh")
      end
    end

    context "com params[:error] presente" do
      it "redireciona com #error=oauth_error e não troca o code" do
        token_stub = stub_request(:post, "https://oauth2.googleapis.com/token")

        get "/auth/callback", params: { error: "access_denied" }

        expect(response).to have_http_status(:found)
        expect(response.location).to eq("#{frontend_url}/auth/callback#error=oauth_error")
        expect(token_stub).not_to have_been_requested
      end
    end

    context "quando exchange_code falha" do
      before do
        stub_request(:post, "https://oauth2.googleapis.com/token")
          .to_return(status: 400, body: '{"error":"invalid_grant"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "redireciona com #error=auth_failed" do
        get "/auth/callback", params: { code: "valid-code" }

        expect(response).to have_http_status(:found)
        expect(response.location).to eq("#{frontend_url}/auth/callback#error=auth_failed")
      end
    end

    context "quando fetch_userinfo falha" do
      before do
        stub_token_exchange
        stub_request(:get, "https://www.googleapis.com/oauth2/v3/userinfo")
          .to_return(status: 401, body: '{"error":"invalid_token"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "redireciona com #error=auth_failed" do
        get "/auth/callback", params: { code: "valid-code" }

        expect(response).to have_http_status(:found)
        expect(response.location).to eq("#{frontend_url}/auth/callback#error=auth_failed")
      end
    end

    private

    def extract_token
      URI.parse(response.location).fragment.delete_prefix("token=")
    end
  end
end
