require "rails_helper"

RSpec.describe "Assignments", type: :request do
  let(:secret)  { "test-secret-key" }
  let(:user)    { create(:user) }
  let(:token)   { JwtService.create_access_token({ "user_id" => user.id }, secret) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before { ENV["SECRET_KEY_BASE"] = secret }
  after  { ENV.delete("SECRET_KEY_BASE") }

  describe "PATCH /assignments/:id/priority" do
    context "com token válido e assignment pertencente ao usuário" do
      let(:assignment) do
        course = create(:course, user: user)
        create(:assignment, user: user, course: course)
      end

      it "retorna 200 com os campos esperados" do
        patch "/assignments/#{assignment.id}/priority",
              params: { manual_priority: 1 }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.keys).to match_array(
          %w[id title manual_priority auto_priority due_date state course_id]
        )
      end

      it "retorna o assignment com a prioridade atualizada" do
        patch "/assignments/#{assignment.id}/priority",
              params: { manual_priority: 1 }, headers: headers

        body = response.parsed_body
        expect(body["id"]).to eq(assignment.id)
        expect(body["manual_priority"]).to eq(1)
        expect(body["course_id"]).to eq(assignment.course_id)
      end

      it "persiste a prioridade manual no banco" do
        patch "/assignments/#{assignment.id}/priority",
              params: { manual_priority: 3 }, headers: headers

        expect(assignment.reload.manual_priority).to eq(3)
      end

      it "aceita nil para limpar a prioridade manual" do
        assignment.update!(manual_priority: 5)
        patch "/assignments/#{assignment.id}/priority",
              params: { manual_priority: nil }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(assignment.reload.manual_priority).to be_nil
      end
    end

    context "com manual_priority inválida" do
      let(:assignment) do
        course = create(:course, user: user)
        create(:assignment, user: user, course: course)
      end

      def patch_priority(value)
        patch "/assignments/#{assignment.id}/priority",
              params: { manual_priority: value }, headers: headers
      end

      it "retorna 422 para valor não numérico" do
        patch_priority("abc")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("invalid_priority")
      end

      it "retorna 422 para zero" do
        patch_priority(0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("invalid_priority")
      end

      it "retorna 422 para valor negativo" do
        patch_priority(-1)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("invalid_priority")
      end

      it "retorna 422 para valor fora do alcance de integer" do
        patch_priority(99_999_999_999_999)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("invalid_priority")
      end

      it "não altera a prioridade persistida" do
        assignment.update!(manual_priority: 5)
        patch_priority("abc")

        expect(assignment.reload.manual_priority).to eq(5)
      end
    end

    context "quando o assignment pertence a outro usuário" do
      let(:other_assignment) do
        other_user = create(:user)
        course = create(:course, user: other_user)
        create(:assignment, user: other_user, course: course)
      end

      it "retorna 404" do
        patch "/assignments/#{other_assignment.id}/priority",
              params: { manual_priority: 1 }, headers: headers

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["error"]).to eq("not_found")
      end
    end

    context "quando o id não existe" do
      it "retorna 404" do
        patch "/assignments/00000000-0000-0000-0000-000000000000/priority",
              params: { manual_priority: 1 }, headers: headers

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["error"]).to eq("not_found")
      end
    end

    context "sem token de autenticação" do
      it "retorna 401" do
        patch "/assignments/00000000-0000-0000-0000-000000000000/priority",
              params: { manual_priority: 1 }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to eq("unauthorized")
      end
    end

    context "com token inválido" do
      it "retorna 401" do
        patch "/assignments/00000000-0000-0000-0000-000000000000/priority",
              params: { manual_priority: 1 },
              headers: { "Authorization" => "Bearer token-invalido" }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to eq("unauthorized")
      end
    end
  end

  describe "POST /assignments/sync" do
    let(:user)   { create(:user, google_access_token: "fake-google-token") }
    let(:course) { create(:course, user: user, google_course_id: "c1") }

    before { course }

    def stub_course_work(course_id, work)
      stub_request(:get, "https://classroom.googleapis.com/v1/courses/#{course_id}/courseWork")
        .with(headers: { "Authorization" => "Bearer fake-google-token" },
              query: hash_including(pageSize: "100"))
        .to_return(status: 200, body: { courseWork: work }.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    context "com token válido e Classroom respondendo com sucesso" do
      before do
        stub_course_work("c1", [
                           { id: "a1", title: "Lista 1", description: "desc",
                             dueDate: { year: 2026, month: 6, day: 1 }, state: "PUBLISHED" },
                           { id: "a2", title: "Lista 2", state: "PUBLISHED" }
                         ])
      end

      it "retorna 200 com synced" do
        post "/assignments/sync", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["synced"]).to eq(2)
      end

      it "persiste os assignments no banco" do
        expect { post "/assignments/sync", headers: headers }
          .to change(Assignment, :count).by(2)
      end

      it "não duplica assignments em chamadas repetidas" do
        post "/assignments/sync", headers: headers
        expect { post "/assignments/sync", headers: headers }
          .not_to change(Assignment, :count)
      end

      it "atualiza title e due_date de assignment existente" do
        post "/assignments/sync", headers: headers

        stub_course_work("c1", [
                           { id: "a1", title: "Lista 1 — Revisada", description: "desc",
                             dueDate: { year: 2026, month: 7, day: 15 }, state: "PUBLISHED" }
                         ])
        post "/assignments/sync", headers: headers

        assignment = Assignment.find_by(google_assignment_id: "a1")
        expect(assignment.title).to eq("Lista 1 — Revisada")
        expect(assignment.due_date).to eq(Date.new(2026, 7, 15))
      end

      it "calcula auto_priority para assignments com due_date" do
        post "/assignments/sync", headers: headers

        assignment = Assignment.find_by(google_assignment_id: "a1")
        expected = (Date.new(2026, 6, 1) - Time.zone.today).to_i
        expect(assignment.auto_priority).to eq([expected, 1].max)
      end

      it "deixa auto_priority nil para assignments sem due_date" do
        post "/assignments/sync", headers: headers

        assignment = Assignment.find_by(google_assignment_id: "a2")
        expect(assignment.due_date).to be_nil
        expect(assignment.auto_priority).to be_nil
      end
    end

    context "quando o courseWork vem paginado" do
      before do
        stub_request(:get, "https://classroom.googleapis.com/v1/courses/c1/courseWork")
          .with(query: { pageSize: "100" })
          .to_return(status: 200,
                     body: { courseWork: [{ id: "a1", title: "Lista 1", state: "PUBLISHED" }],
                             nextPageToken: "tok-2" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        stub_request(:get, "https://classroom.googleapis.com/v1/courses/c1/courseWork")
          .with(query: { pageSize: "100", pageToken: "tok-2" })
          .to_return(status: 200,
                     body: { courseWork: [{ id: "a2", title: "Lista 2", state: "PUBLISHED" }] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "acumula os assignments de todas as páginas" do
        post "/assignments/sync", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["synced"]).to eq(2)
        expect(Assignment.pluck(:google_assignment_id)).to match_array(%w[a1 a2])
      end
    end

    context "quando a API do Classroom retorna erro não-401" do
      before do
        stub_request(:get, "https://classroom.googleapis.com/v1/courses/c1/courseWork")
          .with(query: hash_including(pageSize: "100"))
          .to_return(status: 500, body: '{"error":"internal"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "retorna 502 com classroom_api_error" do
        post "/assignments/sync", headers: headers

        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body["error"]).to eq("classroom_api_error")
        expect(response.parsed_body["message"]).to be_a(String)
      end
    end

    context "quando o access_token expirou (401) e há refresh_token" do
      let(:user) do
        create(:user, google_access_token: "fake-google-token",
                      google_refresh_token: "valid-refresh-token")
      end

      before do
        # 1ª chamada com o token expirado → 401
        stub_request(:get, "https://classroom.googleapis.com/v1/courses/c1/courseWork")
          .with(headers: { "Authorization" => "Bearer fake-google-token" },
                query: hash_including(pageSize: "100"))
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
        stub_request(:get, "https://classroom.googleapis.com/v1/courses/c1/courseWork")
          .with(headers: { "Authorization" => "Bearer novo-token" },
                query: hash_including(pageSize: "100"))
          .to_return(status: 200,
                     body: { courseWork: [{ id: "a1", title: "Lista 1", state: "PUBLISHED" }] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "renova o token e retorna 200 com synced" do
        post "/assignments/sync", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["synced"]).to eq(1)
      end

      it "persiste o novo access_token no usuário" do
        post "/assignments/sync", headers: headers

        expect(user.reload.google_access_token).to eq("novo-token")
      end
    end

    context "quando o access_token expirou (401) e o refresh falha" do
      let(:user) do
        create(:user, google_access_token: "fake-google-token",
                      google_refresh_token: "revoked-refresh-token")
      end

      before do
        stub_request(:get, "https://classroom.googleapis.com/v1/courses/c1/courseWork")
          .with(query: hash_including(pageSize: "100"))
          .to_return(status: 401, body: '{"error":"invalid_credentials"}',
                     headers: { "Content-Type" => "application/json" })

        stub_request(:post, "https://oauth2.googleapis.com/token")
          .to_return(status: 400, body: '{"error":"invalid_grant"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "limpa os tokens e retorna 401 token_expired" do
        post "/assignments/sync", headers: headers

        aggregate_failures do
          expect(response).to have_http_status(:unauthorized)
          expect(response.parsed_body["error"]).to eq("token_expired")
          expect(user.reload.google_access_token).to be_nil
          expect(user.reload.google_refresh_token).to be_nil
        end
      end
    end

    context "sem token de autenticação" do
      it "retorna 401" do
        post "/assignments/sync"

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to eq("unauthorized")
      end
    end
  end
end
