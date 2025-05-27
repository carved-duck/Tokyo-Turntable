class Gig < ApplicationRecord
  belongs_to :venue
  belongs_to :user, optional: true
  has_many :attendances
  has_many :bookings
  has_many :bands, through: :bookings

  has_one_attached :photo

  validates :date, presence: true
  validates :open_time, presence: true
  validates :start_time, presence: true
  validates :price, presence: true
end
