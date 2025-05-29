class VenuesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @venues = policy_scope(Venue)

    if params[:search][:genre].present? && params[:search][:genre] != "All"
      @venues = @venues.joins(gigs: { bookings: :band }).where(bands: { genre: params[:search][:genre] }).distinct
      @available_genres = Band.joins(bookings: { gig: :venue }).where(venues: { id: @venues.pluck(:id) }).distinct.pluck(:genre)
    end

    if params[:search][:address].present?
      @venues = @venues.near(params[:search][:address], params[:search][:radius].to_f, units: :km)
    end

    @markers = @venues.geocoded.map do |venue|
      {
        id: venue.id,
        lat: venue.latitude,
        lng: venue.longitude,
        info_window_html: render_to_string(partial: "info_window", locals: {venue: venue}),
        marker_html: render_to_string(partial: "marker", locals: {venue: venue})
      }
    end
  end

  def show
    @venue = Venue.find(params[:id])
    authorize @venue
  end
end
