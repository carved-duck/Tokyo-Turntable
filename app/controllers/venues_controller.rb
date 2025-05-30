class VenuesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    puts "--- VenuesController#index START ---"
    puts "Is user signed in (Devise check): #{user_signed_in?}"
    puts "Current user object (Devise): #{current_user.inspect}" if user_signed_in?

    @venues = policy_scope(Venue)


     # See the generated SQL quer

#     if params[:search][:genre].present? && params[:search][:genre] != "All"
#       @venues = @venues.joins(gigs: { bookings: :band }).where(bands: { genre: params[:search][:genre] }).distinct
#       @available_genres = Band.joins(bookings: { gig: :venue }).where(venues: { id: @venues.pluck(:id) }).distinct.pluck(:genre)
    if params.dig(:search, :genre).present? && params[:search][:genre] != "All"
      genre = params[:search][:genre]
      filtered = @venues.joins(gigs: { bookings: :band }).where(bands: { genre: genre }).distinct

      if filtered.any?
        @venues = filtered
        @available_genres = Band.joins(bookings: { gig: :venue }).where(venues: { id: @venues.pluck(:id) }).distinct.pluck(:genre)
      else
        flash.now[:alert] = "No venues match genre “#{genre}”. Showing all."
      end
    end

    if params.dig(:search, :address).present?
      address = params[:search][:address]
      radius  = params[:search][:radius].to_f

      if Geocoder.search(address).present?
        near = @venues.near(address, radius, units: :km)
        if near.any?
          @venues = near
        else
          flash.now[:alert] ||= ""
          flash.now[:alert]  += " No venues within #{radius.to_i} km of “#{address}”."
        end
      else
        flash.now[:alert] ||= ""
        flash.now[:alert]  += " Couldn’t find location “#{address}”. Showing all."
      end
    end
    # @filtered_venues = []

    # @venues.each do |venue|
    #   @filtered_venues << venue if @filtered_venues.count{|v|v.latitude == venue.latitude && v.longitude == venue.longitude} < 1
    # end
    #

    @venues = @venues.select(&:unique_coords)

    @markers = @venues.map do |venue|
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
