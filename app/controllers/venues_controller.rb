class VenuesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    puts "--- VenuesController#index START ---"
    puts "Is user signed in (Devise check): #{user_signed_in?}"
    puts "Current user object (Devise): #{current_user.inspect}" if user_signed_in?

    @venues = policy_scope(Venue)

     puts "Result of policy_scope(Venue):"
    puts "  Count: #{@venues.count}"
    puts "  Class: #{@venues.class}"
    puts "  SQL: #{@venues.to_sql}" # See the generated SQL quer

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
    puts "--- VenuesController#show START ---"
    puts "Is user signed in (Devise check): #{user_signed_in?}"
    puts "Current user object (Devise): #{current_user.inspect}" if user_signed_in?
    puts "Authorization performed for show? on venue id #{@venue.id}"
    puts "--- VenuesController#show END ---"
  end
end
