require 'httparty'
require 'base64'
require 'cgi'

class SpotifyService
  include HTTParty
  base_uri 'https://api.spotify.com/v1'

  def initialize
    @client_id     = ENV['SPOTIFY_CLIENT_ID']
    @client_secret = ENV['SPOTIFY_CLIENT_SECRET']
    @access_token  = fetch_access_token
  end

  # ----------------------------------------------------
  # PUBLIC INTERFACE
  # ----------------------------------------------------

  # Given a band name, return the first non‐nil preview_url or nil.
  # Tries known hits in JP → GB → US, then artist → top‐tracks in JP → GB → US.
  def get_band_sample_preview_url(band_name)
    return nil if band_name.blank?

    # 1) Try a few well‐known song titles first
    known_hits = ["High and Dry", "Creep", "Karma Police", "Paranoid Android"]
    known_hits.each do |hit|
      ["JP", "GB", "US"].each do |market|
        preview = search_track_preview_url("#{band_name} #{hit}", market)
        return preview if preview.present?
      end
    end

    # 2) Fallback: look up the artist, then try top‐tracks
    ["JP", "GB", "US"].each do |market|
      artist_id = search_artist(band_name)
      if artist_id
        preview = get_artist_top_tracks(artist_id, market)
        return preview if preview.present?
      end
    end

    nil
  end

  # Search for a single track by full query in the given market.
  # Returns preview_url (string) or nil.
  def search_track_preview_url(query, market = "JP")
    return nil if query.blank?
    _search_track_preview_url(query, market)
  end

  # Search for an artist by name (automatically tries JP → GB → US).
  # Returns the first matching Spotify artist ID (string) or nil.
  def search_artist(artist_name)
    return nil if artist_name.blank?

    clean_name = sanitize_artist_name(artist_name)

    ["JP", "GB", "US"].each do |market|
      id = _search_artist_id(clean_name, market)
      return id if id.present?
    end

    nil
  end

  # Given a Spotify artist ID, fetch top‐tracks in the given market and
  # return the first preview_url (or nil).
  def get_artist_top_tracks(artist_id, market = "JP")
    return nil if artist_id.blank?
    _get_artist_top_preview(artist_id, market)
  end

  # Search for a track and return its Spotify track ID (string) or nil.
  # Looks up the first match in the given market.
  def search_track_id_for_band(band_name, market = "JP")
    return nil if band_name.blank?

    resp = fetch_with_token(
      "/search",
      q:      band_name,
      type:   "track",
      market: market,
      limit:  1
    )

    if resp.success? && resp["tracks"] && resp["tracks"]["items"].any?
      resp["tracks"]["items"][0]["id"]
    else
      nil
    end
  end

  private

  # ----------------------------------------------------
  # HELPERS & RAW ENDPOINT WRAPPERS
  # ----------------------------------------------------

  # Remove any parenthetical qualifiers, e.g. "Thunder Horse (USA)" → "Thunder Horse"
  def sanitize_artist_name(raw_name)
    raw_name.gsub(/\s*\([^)]*\)\s*/, '').strip
  end

  # Raw search for a track by full query in a given market.
  # Returns preview_url (string) or nil.
  def _search_track_preview_url(query, market)
    resp = fetch_with_token(
      "/search",
      q:      query,
      type:   'track',
      market: market,
      limit:  1
    )

    if resp.success? && resp['tracks'] && resp['tracks']['items'].any?
      resp['tracks']['items'][0]['preview_url']
    else
      nil
    end
  end

  # Raw search for an artist ID by name in a given market.
  # Returns artist_id (string) or nil.
  def _search_artist_id(name, market)
    resp = fetch_with_token(
      "/search",
      q:      name,
      type:   'artist',
      market: market,
      limit:  1
    )

    if resp.success? && resp['artists'] && resp['artists']['items'].any?
      resp['artists']['items'][0]['id']
    else
      nil
    end
  end

  # Given artist_id, fetch top‐tracks in a market; return the first preview_url or nil.
  def _get_artist_top_preview(artist_id, market)
    resp = fetch_with_token(
      "/artists/#{artist_id}/top-tracks",
      market: market
    )

    if resp.success? && resp['tracks'].is_a?(Array)
      resp['tracks'].each do |track|
        return track['preview_url'] if track['preview_url'].present?
      end
    end

    nil
  end

  # ----------------------------------------------------
  # TOKEN MANAGEMENT
  # ----------------------------------------------------

  # Exchange client_id/secret for a client_credentials token. Returns string or nil.
  def fetch_access_token
    auth_url = 'https://accounts.spotify.com/api/token'
    resp = HTTParty.post(
      auth_url,
      headers: {
        "Authorization" => "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}",
        "Content-Type"  => "application/x-www-form-urlencoded"
      },
      body: { grant_type: 'client_credentials' }
    )
    resp.success? ? resp['access_token'] : nil
  end

  # Makes a GET request to `path` with `query` params, automatically refreshing the token on 401.
  def fetch_with_token(path, query = {})
    # First attempt with current access token
    resp = self.class.get(
      path,
      headers: { "Authorization" => "Bearer #{@access_token}" },
      query:   query
    )

    # If token expired (401), fetch a fresh token and retry once
    if resp.code == 401
      @access_token = fetch_access_token
      resp = self.class.get(
        path,
        headers: { "Authorization" => "Bearer #{@access_token}" },
        query:   query
      )
    end
    resp
  end
end
