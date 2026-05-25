class Assignment < ApplicationRecord
  belongs_to :course
  belongs_to :user

  VALID_STATES = %w[CREATED TURNED_IN RETURNED RECLAIMED_BY_STUDENT].freeze

  validates :google_assignment_id, presence: true, length: { maximum: 255 }
  validates :title,                presence: true, length: { maximum: 500 }
  validates :state, inclusion: { in: VALID_STATES }

  def self.calculate_auto_priority(due_date)
    return nil if due_date.nil?

    days_until_due = (due_date.to_date - Time.zone.today).to_i
    [days_until_due, 1].max
  end
end
