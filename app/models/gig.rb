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

  has_many :favorites, as: :favoritable, dependent: :destroy # This explicitly defines the inverse association
  acts_as_favoritable # Means that this model can be favourited

  def formatted_start_time
    (DateTime.parse("#{self.date.strftime("%Y-%m-%d")} #{self.open_time.gsub(".",":")}:00") + 30.minutes).strftime("%H:%M")
  end
end
