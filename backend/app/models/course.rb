class Course < ApplicationRecord
  belongs_to :user
  has_many   :assignments, dependent: :destroy

  validates :google_course_id, presence: true, length: { maximum: 255 }
  validates :name,             presence: true, length: { maximum: 500 }
  validates :section,          length: { maximum: 255 }, allow_nil: true
end
