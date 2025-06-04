# frozen_string_literal: true

class Favorite < ApplicationRecord
  extend ActsAsFavoritor::FavoriteScopes

  belongs_to :favoritable, polymorphic: true
  belongs_to :favoritor, polymorphic: true

  belongs_to :user, foreign_key: :favoritor_id, class_name: 'User', optional: true

  def block!
    update!(blocked: true)
  end
end
