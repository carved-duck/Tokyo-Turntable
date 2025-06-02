class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :attendances
  belongs_to :band, optional: true
  validates :username, presence: true
  has_one_attached :photo

  acts_as_favoritor # Means that this model can favourite other models
end
