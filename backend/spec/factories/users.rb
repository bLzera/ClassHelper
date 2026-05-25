FactoryBot.define do
  factory :user do
    sequence(:google_id) { |n| "google_id_#{n}" }
    sequence(:email)     { |n| "user#{n}@example.com" }
    name                 { "Test User" }
    google_access_token  { "fake-access-token" }
    google_refresh_token { nil }
  end
end
