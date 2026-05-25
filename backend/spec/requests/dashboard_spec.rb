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
          %w[id title description due_date state manual_priority auto_priority course_id]
        )
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
