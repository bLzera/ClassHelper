FactoryBot.define do
  factory :assignment do
    association :user
    association :course
    sequence(:google_assignment_id) { |n| "google_assignment_#{n}" }
    sequence(:title)                { |n| "Assignment #{n}" }
    state                           { "CREATED" }
    manual_priority                 { nil }
    auto_priority                   { nil }
    due_date                        { nil }
    description                     { nil }
  end
end
