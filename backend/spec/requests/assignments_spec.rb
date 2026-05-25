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
end
