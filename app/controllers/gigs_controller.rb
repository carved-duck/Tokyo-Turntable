class GigsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    # @gigs = Gig.all
    @gigs = policy_scope(Gig)
    @gigs = filter_by_genre(@gigs)
    @gigs = filter_by_location(@gigs)

    # remove exact‐duplicate markers (round lat/lng to 5 decimals, for example)
    @gigs = @gigs.uniq { |g| [ g.venue.latitude&.round(5), g.venue.longitude&.round(5) ] }

    # build @markers for Mapbox, pulling lat/lng out of each gig’s venue
    @markers = @gigs.map { |gig| marker_data_for(gig) }
  end

  def show
    @gig = Gig.find(params[:id])
    authorize @gig
  end

  def edit
  end

  def update
  end

  def destroy
  end

  private
  # This is for keeping gigs whose band-genre matches the selected param
  def filter_by_genre(scope)
    genre = params.dig(:search, :genre)
    return scope if genre.blank? || genre == "All"

    # join through bookings→band to filter gigs by band genre
    filtered = scope
      .joins( bookings: :band )
      .where(bands: { genre: genre })
      .distinct

    if filtered.any?
      # If you want to rebuild the “available genres” dropdown based on this filtered set:
      @available_genres = Band
        .joins(bookings: :gig)
        .where(bookings: { gig_id: filtered.pluck(:id) })
        .distinct
        .pluck(:genre)
      filtered
    else
      flash.now[:alert] = "No gigs match genre '#{genre}'. Showing all."
      scope
    end
  end

    # This is for filtering by location! TOOOOOOO CHANGE
    def filter_by_location(scope)
      address = params.dig(:search, :address)
      radius  = params.dig(:search, :radius)&.to_f || 5
      return scope if address.blank?

      # Check if Geocoder can find that address
      if Geocoder.search(address).present?
        # Find all venues near that address, then pick gigs whose venue_id is in that set
        nearby_venue_ids = Venue.near(address, radius, units: :km, order: false).pluck(:id)
        if nearby_venue_ids.any?
          scope.where(venue_id: nearby_venue_ids)
        else
          flash.now[:alert] ||= ""
          flash.now[:alert] += " No venues within #{radius.to_i} km of '#{address}'. Showing all gigs."
          scope
        end
      else
        flash.now[:alert] ||= ""
        flash.now[:alert] += " Couldn't find location '#{address}'. Showing all gigs."
        scope
      end
    end

    def marker_data_for(gig)
      {
        id: gig.id,
        lat: gig.venue.latitude,
        lng: gig.venue.longitude,
        info_window_html: render_to_string(partial: "gigs/info_window", locals: { gig: gig }),
        marker_html: render_to_string(partial: "gigs/marker", locals: { gig: gig })
      }
    end
end
