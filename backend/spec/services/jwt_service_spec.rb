require "spec_helper"
require_relative "../../app/services/jwt_service"

RSpec.describe JwtService do
  let(:secret) { "test-secret-key" }
  let(:payload) { { "user_id" => "abc123" } }

  describe ".create_access_token" do
    it "returns a JWT string" do
      token = described_class.create_access_token(payload, secret)
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end

    it "encodes the user_id in the payload" do
      token = described_class.create_access_token(payload, secret)
      decoded = described_class.decode_access_token(token, secret)
      expect(decoded["user_id"]).to eq("abc123")
    end

    it "sets expiration 30 minutes from now" do
      token = described_class.create_access_token(payload, secret)
      decoded = described_class.decode_access_token(token, secret)
      expect(decoded["exp"]).to be_within(5).of(Time.now.utc.to_i + 1800)
    end
  end

  describe ".decode_access_token" do
    it "raises JWT::DecodeError for invalid token" do
      expect do
        described_class.decode_access_token("invalid.token.here", secret)
      end.to raise_error(JWT::DecodeError)
    end

    it "raises JWT::ExpiredSignature for expired token" do
      expired_payload = payload.merge("exp" => Time.now.utc.to_i - 1)
      token = JWT.encode(expired_payload, secret, "HS256")
      expect do
        described_class.decode_access_token(token, secret)
      end.to raise_error(JWT::ExpiredSignature)
    end
  end
end
