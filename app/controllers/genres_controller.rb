class GenresController < ApplicationController
  def index
    term = params[:q]
    genres = if term.present?
      Band.distinct.where(genre ILIKE ?", "%#{term}%").pluck(:genre)
    else
      Band.distinct.pluck(:genre)
    end
  render json: genres.map { |g| { value: g, text: g } }
  end
end
