class User < ApplicationRecord
  has_many :courses,     dependent: :destroy
  has_many :assignments, dependent: :destroy

  validates :google_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :email,      presence: true, uniqueness: true, length: { maximum: 255 }
  validates :name,       presence: true,                   length: { maximum: 255 }
  validates :google_access_token,  length: { maximum: 2048 }, allow_nil: true
  validates :google_refresh_token, length: { maximum: 2048 }, allow_nil: true
end
