require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:secret)  { "test-secret-key" }
  let(:user)    { create(:user) }
  let(:course)  { create(:course, user: user) }
  let(:token)   { JwtService.create_access_token({ "user_id" => user.id }, secret) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before { ENV["SECRET_KEY_BASE"] = secret }
  after  { ENV.delete("SECRET_KEY_BASE") }

  describe "GET /dashboard" do
    context "com token válido e assignments no estado CREATED" do
      it "retorna 200 com a lista ordenada por prioridade efetiva" do
        low  = create(:assignment, user: user, course: course, auto_priority: 10)
        high = create(:assignment, user: user, course: course, auto_priority: 1)
        mid  = create(:assignment, user: user, course: course, auto_priority: 5)

        get "/dashboard", headers: headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([high.id, mid.id, low.id])
      end

      it "retorna os campos esperados em cada assignment" do
        create(:assignment, user: user, course: course, auto_priority: 1)

        get "/dashboard", headers: headers

        expect(response.parsed_body["assignments"].first.keys).to match_array(
          %w[id title description due_date state manual_priority auto_priority course_id alternate_link]
        )
      end

      it "inclui alternate_link no JSON de cada assignment" do
        create(:assignment, user: user, course: course, auto_priority: 1,
                            alternate_link: "https://classroom.google.com/c/abc/a/xyz/details")

        get "/dashboard", headers: headers

        first = response.parsed_body["assignments"].first
        expect(first).to have_key("alternate_link")
        expect(first["alternate_link"]).to eq("https://classroom.google.com/c/abc/a/xyz/details")
      end
    end

    context "com assignments em estados diferentes de CREATED" do
      it "não inclui TURNED_IN, RETURNED nem RECLAIMED_BY_STUDENT" do
        created = create(:assignment, user: user, course: course, state: "CREATED", auto_priority: 1)
        create(:assignment, user: user, course: course, state: "TURNED_IN", auto_priority: 2)
        create(:assignment, user: user, course: course, state: "RETURNED", auto_priority: 3)
        create(:assignment, user: user, course: course, state: "RECLAIMED_BY_STUDENT", auto_priority: 4)

        get "/dashboard", headers: headers

        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([created.id])
      end
    end

    context "prioridade efetiva" do
      it "usa manual_priority com precedência sobre auto_priority" do
        manual = create(:assignment, user: user, course: course, manual_priority: 1, auto_priority: 99)
        auto   = create(:assignment, user: user, course: course, manual_priority: nil, auto_priority: 2)

        get "/dashboard", headers: headers

        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([manual.id, auto.id])
      end

      it "coloca assignments sem nenhuma prioridade por último (NULLS LAST)" do
        with_priority = create(:assignment, user: user, course: course, auto_priority: 5)
        without       = create(:assignment, user: user, course: course, manual_priority: nil, auto_priority: nil)

        get "/dashboard", headers: headers

        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([with_priority.id, without.id])
      end
    end

    context "com completed=false explícito" do
      it "retorna só os assignments CREATED, ordenados por prioridade efetiva" do
        low  = create(:assignment, user: user, course: course, state: "CREATED", auto_priority: 10)
        high = create(:assignment, user: user, course: course, state: "CREATED", auto_priority: 1)
        create(:assignment, user: user, course: course, state: "TURNED_IN", auto_priority: 1)

        get "/dashboard", params: { completed: "false" }, headers: headers

        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([high.id, low.id])
      end
    end

    context "com completed=true" do
      it "retorna só os assignments TURNED_IN" do
        turned_in = create(:assignment, user: user, course: course, state: "TURNED_IN",
                                        due_date: 5.days.from_now)
        create(:assignment, user: user, course: course, state: "CREATED", auto_priority: 1)
        create(:assignment, user: user, course: course, state: "RETURNED", due_date: 1.day.from_now)

        get "/dashboard", params: { completed: "true" }, headers: headers

        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([turned_in.id])
      end

      it "ordena os concluídos por due_date DESC NULLS LAST" do
        turned_in = ->(due) { create(:assignment, user: user, course: course, state: "TURNED_IN", due_date: due) }
        oldest  = turned_in.call(1.day.from_now)
        newest  = turned_in.call(10.days.from_now)
        mid     = turned_in.call(5.days.from_now)
        no_date = turned_in.call(nil)

        get "/dashboard", params: { completed: "true" }, headers: headers

        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([newest.id, mid.id, oldest.id, no_date.id])
      end

      it "retorna lista vazia quando não há concluídos" do
        create(:assignment, user: user, course: course, state: "CREATED", auto_priority: 1)

        get "/dashboard", params: { completed: "true" }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["assignments"]).to eq([])
      end
    end

    context "quando o usuário não tem assignments" do
      it "retorna 200 com lista vazia" do
        get "/dashboard", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["assignments"]).to eq([])
      end
    end

    context "escopo por usuário" do
      it "não inclui assignments de outro usuário" do
        own = create(:assignment, user: user, course: course, auto_priority: 1)

        other_user   = create(:user)
        other_course = create(:course, user: other_user)
        create(:assignment, user: other_user, course: other_course, auto_priority: 1)

        get "/dashboard", headers: headers

        ids = response.parsed_body["assignments"].pluck("id")
        expect(ids).to eq([own.id])
      end
    end

    context "sem token de autenticação" do
      it "retorna 401" do
        get "/dashboard"

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to eq("unauthorized")
      end
    end

    context "com token inválido" do
      it "retorna 401" do
        get "/dashboard", headers: { "Authorization" => "Bearer token-invalido" }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to eq("unauthorized")
      end
    end
  end
end
