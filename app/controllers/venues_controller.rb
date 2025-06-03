class VenuesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @venues = policy_scope(Venue)
    if params[:query].present?
      @venues = @venues.global_search(params[:query])
    end
  end

  def show
    @venue = Venue.find(params[:id])
    authorize @venue
  end
end
