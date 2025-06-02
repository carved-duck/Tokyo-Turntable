class GigsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    # @gigs = Gig.all
    @gigs = policy_scope(Gig)
    @gigs = filter_by_date(@gigs)
    @gigs = filter_by_genre(@gigs)

    # remove exact‐duplicate markers (round lat/lng to 5 decimals, for example)
    @gigs = @gigs.uniq { |g| [ g.venue.latitude&.round(5), g.venue.longitude&.round(5) ] }

    # build @markers for Mapbox, pulling lat/lng out of each gig’s venue
    @markers = @gigs.map { |gig| marker_data_for(gig) }
  end

  def show
    @gig = Gig.find(params[:id])
    @venue = Venue.find(@gig.venue_id)
    authorize @gig
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
