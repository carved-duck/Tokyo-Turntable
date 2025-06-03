class Venue < ApplicationRecord
  has_many :gigs

  has_one_attached :photo

  validates :name, presence: true
  validates :address, presence: true
  validates :email, presence: true
  validates :neighborhood, presence: true
  validates :details, presence: true

  geocoded_by :address
  after_validation :geocode, if: :will_save_change_to_address?
  acts_as_favoritable # Allows gigs to be followed/favorited by others
end
