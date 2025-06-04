# app/controllers/gigs_controller.rb

class GigsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @gigs = policy_scope(Gig)
    @gigs = filter_by_date(@gigs)
    @gigs = filter_by_genre(@gigs)

    # removes duplicate markers(round lat/lng to 5 decimals)
    @gigs = @gigs.uniq { |g| [ g.venue.latitude&.round(5), g.venue.longitude&.round(5) ] }
    # build @markers for Mapbox, pulling lat/lng out of each gig’s venue
    @markers = @gigs.map { |gig| marker_data_for(gig) }
  end

  def show
    # --- START CHANGE ---
    # Eager load favorites and the associated user to avoid N+1 queries in the view
    @gig = Gig.includes(favorites: :user).find(params[:id]) #
    # --- END CHANGE ---
    @venue = Venue.find(@gig.venue_id)
    authorize @gig
    # ─── NEW: fetch Spotify artist IDs for every band on this gig ───
    spotify_service = SpotifyService.new
    # For each band, prefer a hard-coded spotify_artist_url (if you added that), otherwise auto-search:
    @artist_ids = @gig.bands.map do |band|
      if band.respond_to?(:spotify_artist_url) && band.spotify_artist_url.present?
        # extract ID from the stored URL
        URI.parse(band.spotify_artist_url).path.split('/').last
      else
        spotify_service.search_artist(band.name)
      end
    end.compact
  end

  def edit
  end

  def update
  end

  def destroy
  end

  private

  def filter_by_date(scope)
    raw_date = params.dig(:search, :select_a_date)
    return scope if raw_date.blank?

    begin
      chosen = Date.parse(raw_date)
    rescue ArgumentError
      flash.now[:alert] = "Couldn't understand “#{raw_date}” as a date. Showing all gigs."
      return scope
    end

    matched = scope.where(date: chosen)
    if matched.any?
      matched
    else
      flash.now[:alert] = "No gigs on #{chosen.strftime('%Y/%m/%d')}. Showing all gigs."
      scope
    end
  end
  # This is for keeping gigs whose band-genre matches the selected param
  def filter_by_genre(scope)
    raw_genres = Array(params.dig(:search, :genre))
    chosen = raw_genres.reject(&:blank?)
    return scope if chosen.empty? || chosen.include?("All")

    # join through bookings→band to filter gigs by band genre
    filtered = scope
      .joins( bookings: :band )
      .where(bands: { genre: chosen })
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
      flash.now[:alert] = "No gigs match genre '#{chosen.inspect}'. Showing all."
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
