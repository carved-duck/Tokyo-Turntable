class VenuesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @venues = policy_scope(Venue)
    @venues = filter_by_genre(@venues)
    @venues = filter_by_location(@venues)

    # de‑dupe exact coordinate duplicates (rounding to 5 decimal places)
    @venues = @venues.uniq { |v| [v.latitude.round(5), v.longitude.round(5)] }

    @markers = @venues.map { |venue| marker_data_for(venue) }
  end

  def show
    @venue = Venue.find(params[:id])
    authorize @venue
  end

  private

  def filter_by_genre(scope)
    genre = params.dig(:search, :genre)
    return scope if genre.blank? || genre == "All"

    filtered = scope
      .joins(gigs: { bookings: :band })
      .where(bands: { genre: genre })
      .distinct

    if filtered.any?
      @available_genres = Band
        .joins(bookings: { gig: :venue })
        .where(venues: { id: filtered.pluck(:id) })
        .distinct
        .pluck(:genre)
      filtered
    else
      flash.now[:alert] = "No venues match genre '#{genre}', showing all."
      scope
    end
  end

  def filter_by_location(scope)
    address = params.dig(:search, :address)
    radius  = params.dig(:search, :radius)&.to_f || 5
    return scope if address.blank?

    if Geocoder.search(address).present?
      near = scope.near(address, radius, units: :km)
      if near.any?
        near
      else
        flash.now[:alert] ||= ''
        flash.now[:alert] += " No venues within #{radius.to_i} km of '#{address}', showing all."
        scope
      end
    else
      flash.now[:alert] ||= ''
      flash.now[:alert] += " Couldn't find location '#{address}', showing all."
      scope
    end
  end

  def marker_data_for(venue)
    {
      id: venue.id,
      lat: venue.latitude,
      lng: venue.longitude,
      info_window_html: render_to_string(partial: "info_window", locals: { venue: venue }),
      marker_html:      render_to_string(partial: "marker",      locals: { venue: venue })
    }
  end
end
