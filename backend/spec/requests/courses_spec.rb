require "rails_helper"

RSpec.describe "Courses", type: :request do
  let(:secret) { "test-secret-key" }
  let(:user)   { create(:user, google_access_token: "fake-google-token") }
  let(:token)  { JwtService.create_access_token({ "user_id" => user.id }, secret) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before { ENV["SECRET_KEY_BASE"] = secret }
  after  { ENV.delete("SECRET_KEY_BASE") }

  describe "POST /courses/sync" do
    context "com token válido e Classroom respondendo com sucesso" do
      let(:classroom_payload) do
        {
          courses: [
            { id: "c1", name: "Cálculo I", section: "T1" },
            { id: "c2", name: "Álgebra Linear" }
          ]
        }.to_json
      end

      before do
        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(
            headers: { "Authorization" => "Bearer fake-google-token" },
            query: { courseStates: "ACTIVE" }
          )
          .to_return(status: 200, body: classroom_payload,
                     headers: { "Content-Type" => "application/json" })
      end

      it "retorna 200 com synced e courses" do
        post "/courses/sync", headers: headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["synced"]).to eq(2)
        expect(body["courses"].pluck("google_course_id")).to match_array(%w[c1 c2])
      end

      it "persiste os cursos no banco" do
        expect { post "/courses/sync", headers: headers }.to change(Course, :count).by(2)
      end

      it "não duplica cursos em chamadas repetidas" do
        post "/courses/sync", headers: headers
        expect { post "/courses/sync", headers: headers }.not_to change(Course, :count)
      end

      it "atualiza o nome de um curso existente" do
        post "/courses/sync", headers: headers

        updated_payload = { courses: [{ id: "c1", name: "Cálculo I — Revisado", section: "T1" }] }.to_json
        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(query: { courseStates: "ACTIVE" })
          .to_return(status: 200, body: updated_payload,
                     headers: { "Content-Type" => "application/json" })

        post "/courses/sync", headers: headers

        expect(Course.find_by(google_course_id: "c1").name).to eq("Cálculo I — Revisado")
      end
    end

    context "sem token de autenticação" do
      it "retorna 401" do
        post "/courses/sync"
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to eq("unauthorized")
      end
    end

    context "quando a API do Classroom retorna erro não-401" do
      before do
        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(query: { courseStates: "ACTIVE" })
          .to_return(status: 500, body: '{"error":"internal"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "retorna 502 com classroom_api_error" do
        post "/courses/sync", headers: headers
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body["error"]).to eq("classroom_api_error")
      end
    end

    context "quando o access_token expirou (401) e há refresh_token" do
      let(:user) do
        create(:user, google_access_token: "expired-token",
                      google_refresh_token: "valid-refresh-token")
      end
      let(:classroom_payload) { { courses: [{ id: "c1", name: "Cálculo I" }] }.to_json }

      before do
        # 1ª chamada com o token expirado → 401
        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(headers: { "Authorization" => "Bearer expired-token" },
                query: { courseStates: "ACTIVE" })
          .to_return(status: 401, body: '{"error":"invalid_credentials"}',
                     headers: { "Content-Type" => "application/json" })

        # refresh do token
        stub_request(:post, "https://oauth2.googleapis.com/token")
          .with(body: hash_including(grant_type: "refresh_token",
                                     refresh_token: "valid-refresh-token"))
          .to_return(status: 200,
                     body: { access_token: "novo-token", expires_in: 3599 }.to_json,
                     headers: { "Content-Type" => "application/json" })

        # retry com o novo token → sucesso
        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(headers: { "Authorization" => "Bearer novo-token" },
                query: { courseStates: "ACTIVE" })
          .to_return(status: 200, body: classroom_payload,
                     headers: { "Content-Type" => "application/json" })
      end

      it "renova o token e retorna 200 com os cursos" do
        post "/courses/sync", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["synced"]).to eq(1)
      end

      it "persiste o novo access_token no usuário" do
        post "/courses/sync", headers: headers

        expect(user.reload.google_access_token).to eq("novo-token")
      end
    end

    context "quando o access_token expirou (401) e o refresh falha" do
      let(:user) do
        create(:user, google_access_token: "expired-token",
                      google_refresh_token: "revoked-refresh-token")
      end

      before do
        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(query: { courseStates: "ACTIVE" })
          .to_return(status: 401, body: '{"error":"invalid_credentials"}',
                     headers: { "Content-Type" => "application/json" })

        stub_request(:post, "https://oauth2.googleapis.com/token")
          .to_return(status: 400, body: '{"error":"invalid_grant"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "limpa os tokens e retorna 401 token_expired" do
        post "/courses/sync", headers: headers

        aggregate_failures do
          expect(response).to have_http_status(:unauthorized)
          expect(response.parsed_body["error"]).to eq("token_expired")
          expect(user.reload.google_access_token).to be_nil
          expect(user.reload.google_refresh_token).to be_nil
        end
      end
    end
  end
end
