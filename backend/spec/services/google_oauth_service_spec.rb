require "rails_helper"

RSpec.describe GoogleOauthService do
  subject(:service) do
    described_class.new(
      client_id: "client-id",
      client_secret: "client-secret",
      redirect_uri: "http://localhost:3000/auth/callback"
    )
  end

  let(:token_url) { "https://oauth2.googleapis.com/token" }

  describe "#refresh_access_token" do
    context "com refresh_token válido" do
      before do
        stub_request(:post, token_url)
          .with(body: {
                  client_id: "client-id",
                  client_secret: "client-secret",
                  refresh_token: "valid-refresh-token",
                  grant_type: "refresh_token"
                })
          .to_return(
            status: 200,
            body: { access_token: "novo-access-token", expires_in: 3599 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "retorna o novo access_token" do
        result = service.refresh_access_token("valid-refresh-token")

        expect(result["access_token"]).to eq("novo-access-token")
        expect(result["expires_in"]).to eq(3599)
      end
    end

    context "com refresh_token inválido" do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 400,
            body: { error: "invalid_grant" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "levanta GoogleOauthService::RefreshError" do
        expect { service.refresh_access_token("bad-refresh-token") }
          .to raise_error(GoogleOauthService::RefreshError)
      end
    end
  end
end
