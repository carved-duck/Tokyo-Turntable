class Attendance < ApplicationRecord
  belongs_to :gig
  belongs_to :user

  validates :attended, default: false
end
