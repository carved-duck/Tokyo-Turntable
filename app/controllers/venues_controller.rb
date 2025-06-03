class VenuesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @venues = policy_scope(Venue)
    @venues = Venue.all
    if params[:query].present?
      # @venues = @venues.joins(gigs: { bookings: :band }).distinct
      sql_subquery = <<~SQL
      venues.name ILIKE :query
      OR venues.neighborhood ILIKE :query
      OR venues.address ILIKE :query
      OR bands.name ILIKE :query
      OR bands.genre ILIKE :query
      SQL
      @venues = @venues.joins(gigs: { bookings: :band }).distinct.where(sql_subquery, query: "%#{params[:query]}%")
    end
  end

  def show
    @venue = Venue.find(params[:id])
    authorize @venue
  end
end
