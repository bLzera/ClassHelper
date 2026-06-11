require "rails_helper"

RSpec.describe "Courses", type: :request do
  let(:secret) { "test-secret-key" }
  let(:user)   { create(:user, google_access_token: "fake-google-token") }
  let(:token)  { JwtService.create_access_token({ "user_id" => user.id }, secret) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before { ENV["SECRET_KEY_BASE"] = secret }
  after  { ENV.delete("SECRET_KEY_BASE") }

  describe "GET /courses" do
    context "com token válido" do
      it "retorna 200 com a lista de cursos do usuário" do
        create(:course, user: user, name: "Cálculo I")
        create(:course, user: user, name: "Álgebra Linear")

        get "/courses", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["courses"].size).to eq(2)
      end

      it "ordena os cursos por name ascendente" do
        create(:course, user: user, name: "Zoologia")
        create(:course, user: user, name: "Anatomia")
        create(:course, user: user, name: "Microbiologia")

        get "/courses", headers: headers

        names = response.parsed_body["courses"].pluck("name")
        expect(names).to eq(%w[Anatomia Microbiologia Zoologia])
      end

      it "expõe id e google_course_id de cada curso" do
        create(:course, user: user, google_course_id: "gc-1", name: "Cálculo I", section: "T1")

        get "/courses", headers: headers

        course = response.parsed_body["courses"].first
        expect(course["id"]).to be_present
        expect(course["google_course_id"]).to eq("gc-1")
      end

      it "expõe name e section de cada curso" do
        create(:course, user: user, google_course_id: "gc-1", name: "Cálculo I", section: "T1")

        get "/courses", headers: headers

        course = response.parsed_body["courses"].first
        expect(course["name"]).to eq("Cálculo I")
        expect(course["section"]).to eq("T1")
      end

      it "calcula pending_count como o nº de assignments CREATED" do
        course = create(:course, user: user)
        create(:assignment, user: user, course: course, state: "CREATED")
        create(:assignment, user: user, course: course, state: "CREATED")
        create(:assignment, user: user, course: course, state: "TURNED_IN")

        get "/courses", headers: headers

        expect(response.parsed_body["courses"].first["pending_count"]).to eq(2)
      end

      it "retorna next_due_date como o menor due_date entre os pendentes" do
        course = create(:course, user: user)
        create(:assignment, user: user, course: course, state: "CREATED",
                            due_date: 5.days.from_now)
        soonest = create(:assignment, user: user, course: course, state: "CREATED",
                                      due_date: 2.days.from_now)
        create(:assignment, user: user, course: course, state: "CREATED",
                            due_date: 10.days.from_now)

        get "/courses", headers: headers

        next_due = response.parsed_body["courses"].first["next_due_date"]
        expect(Time.zone.parse(next_due).to_i).to be_within(1).of(soonest.due_date.to_i)
      end

      it "ignora due_date de assignments não-pendentes ao calcular next_due_date" do
        course = create(:course, user: user)
        create(:assignment, user: user, course: course, state: "TURNED_IN",
                            due_date: 1.day.from_now)
        pending = create(:assignment, user: user, course: course, state: "CREATED",
                                      due_date: 7.days.from_now)

        get "/courses", headers: headers

        next_due = response.parsed_body["courses"].first["next_due_date"]
        expect(Time.zone.parse(next_due).to_i).to be_within(1).of(pending.due_date.to_i)
      end

      it "retorna next_due_date null quando não há pendente com prazo" do
        course = create(:course, user: user)
        create(:assignment, user: user, course: course, state: "CREATED", due_date: nil)

        get "/courses", headers: headers

        expect(response.parsed_body["courses"].first["next_due_date"]).to be_nil
      end

      it "retorna pending_count 0 e next_due_date null para cursos sem assignments" do
        create(:course, user: user)

        get "/courses", headers: headers

        course = response.parsed_body["courses"].first
        expect(course["pending_count"]).to eq(0)
        expect(course["next_due_date"]).to be_nil
      end

      it "retorna apenas os cursos do current_user" do
        create(:course, user: user, name: "Meu Curso")
        other_user = create(:user)
        create(:course, user: other_user, name: "Curso Alheio")

        get "/courses", headers: headers

        names = response.parsed_body["courses"].pluck("name")
        expect(names).to eq(["Meu Curso"])
      end
    end

    context "sem token de autenticação" do
      it "retorna 401" do
        get "/courses"

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to eq("unauthorized")
      end
    end
  end

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
            query: hash_including(courseStates: "ACTIVE")
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
          .with(query: hash_including(courseStates: "ACTIVE"))
          .to_return(status: 200, body: updated_payload,
                     headers: { "Content-Type" => "application/json" })

        post "/courses/sync", headers: headers

        expect(Course.find_by(google_course_id: "c1").name).to eq("Cálculo I — Revisado")
      end
    end

    context "quando a resposta do Classroom vem paginada" do
      before do
        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(query: { courseStates: "ACTIVE", pageSize: "100" })
          .to_return(status: 200,
                     body: { courses: [{ id: "c1", name: "Cálculo I" }],
                             nextPageToken: "tok-2" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        stub_request(:get, "https://classroom.googleapis.com/v1/courses")
          .with(query: { courseStates: "ACTIVE", pageSize: "100", pageToken: "tok-2" })
          .to_return(status: 200,
                     body: { courses: [{ id: "c2", name: "Álgebra Linear" }] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "acumula os cursos de todas as páginas" do
        post "/courses/sync", headers: headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["synced"]).to eq(2)
        expect(body["courses"].pluck("google_course_id")).to match_array(%w[c1 c2])
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
          .with(query: hash_including(courseStates: "ACTIVE"))
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
                query: hash_including(courseStates: "ACTIVE"))
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
                query: hash_including(courseStates: "ACTIVE"))
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
          .with(query: hash_including(courseStates: "ACTIVE"))
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
