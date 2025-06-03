class Band < ApplicationRecord
  has_many :bookings
  has_many :gigs, through: :bookings
  has_many :users

  validates :name, presence: true
  validates :genre, presence: true
  validates :hometown, presence: true
  validates :email, presence: true

  acts_as_favoritable # Allows Band to be followed/favorited by others
end
