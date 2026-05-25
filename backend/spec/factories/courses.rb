FactoryBot.define do
  factory :course do
    association :user
    sequence(:google_course_id) { |n| "google_course_#{n}" }
    sequence(:name)             { |n| "Course #{n}" }
    section                     { nil }
  end
end
