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

  # Enhanced search for an artist by name with better validation
  # Returns the first matching Spotify artist ID (string) or nil.
  def search_artist(artist_name)
    return nil if artist_name.blank?

    # Pre-filter obviously bad band names
    return nil unless valid_band_name?(artist_name)

    clean_name = sanitize_artist_name(artist_name)
    return nil if clean_name.blank? || clean_name.length < 2

    ["JP", "GB", "US"].each do |market|
      artist_data = _search_artist_with_validation(clean_name, market)
      return artist_data[:id] if artist_data
    end

    nil
  end

  # Search with confidence scoring to avoid random matches
  def search_artist_with_confidence(artist_name)
    return { id: nil, confidence: 0, reason: "blank name" } if artist_name.blank?
    return { id: nil, confidence: 0, reason: "invalid name" } unless valid_band_name?(artist_name)

    clean_name = sanitize_artist_name(artist_name)
    return { id: nil, confidence: 0, reason: "name too short" } if clean_name.blank? || clean_name.length < 2

    ["JP", "GB", "US"].each do |market|
      result = _search_artist_with_validation(clean_name, market)
      if result
        confidence = calculate_match_confidence(clean_name, result[:name], result[:popularity])
        return {
          id: result[:id],
          confidence: confidence,
          matched_name: result[:name],
          popularity: result[:popularity],
          reason: "found in #{market}"
        } if confidence > 75 # Only return high-confidence matches
      end
    end

    { id: nil, confidence: 0, reason: "no confident match found" }
  end

  # Given a band name, return the first non‐nil preview_url or nil.
  # Tries known hits in JP → GB → US, then artist → top‐tracks in JP → GB → US.
  def get_band_sample_preview_url(band_name)
    return nil if band_name.blank? || !valid_band_name?(band_name)

    clean_name = sanitize_artist_name(band_name)
    return nil if clean_name.blank?

    # 1) Try a few well‐known song titles first (but only for reasonable band names)
    if clean_name.length > 3 && !clean_name.match?(/live|show|event|performance/i)
      known_hits = ["High and Dry", "Creep", "Karma Police", "Paranoid Android"]
      known_hits.each do |hit|
        ["JP", "GB", "US"].each do |market|
          preview = search_track_preview_url("#{clean_name} #{hit}", market)
          return preview if preview.present?
        end
      end
    end

    # 2) Fallback: look up the artist, then try top‐tracks
    ["JP", "GB", "US"].each do |market|
      artist_data = _search_artist_with_validation(clean_name, market)
      if artist_data
        preview = get_artist_top_tracks(artist_data[:id], market)
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

  # Given a Spotify artist ID, fetch top‐tracks in the given market and
  # return the first preview_url (or nil).
  def get_artist_top_tracks(artist_id, market = "JP")
    return nil if artist_id.blank?
    _get_artist_top_preview(artist_id, market)
  end

  # Search for a track and return its Spotify track ID (string) or nil.
  # Looks up the first match in the given market.
  def search_track_id_for_band(band_name, market = "JP")
    return nil if band_name.blank? || !valid_band_name?(band_name)

    clean_name = sanitize_artist_name(band_name)
    return nil if clean_name.blank?

    resp = fetch_with_token(
      "/search",
      q:      clean_name,
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
  # VALIDATION & FILTERING
  # ----------------------------------------------------

  # Check if a band name is worth searching for on Spotify
  def valid_band_name?(name)
    return false if name.blank?

    # Filter out obvious non-band names
    invalid_patterns = [
      /^live performance$/i,
      /^\d{4}\.\d{1,2}\.\d{1,2}/,  # Date patterns like "2025.7.13"
      /one\s*man\s*live/i,
      /release\s*live/i,
      /pickup\s*event/i,
      /^dj\s/i,
      /cocolofgpa\.instance/i,
      /^(sun|mon|tue|wed|thu|fri|sat)\.?\s/i,
      /\+1drink/i,
      /¥\d+/,
      /focus\s*on\s*the\s*goodies/i,
      /detail$/i,
      /^(the\s+)?show$/i,
      /^event$/i,
      /^live$/i,
      /^performance$/i
    ]

    return false if invalid_patterns.any? { |pattern| name.match?(pattern) }

    # Filter out very short names (likely too generic)
    return false if name.length < 2

    # Filter out names that are mostly numbers/symbols
    return false if name.gsub(/[a-zA-Zひらがなカタカナ漢字]/, '').length > name.length * 0.7

    true
  end

    # Calculate confidence score for a Spotify match
  def calculate_match_confidence(search_name, found_name, popularity)
    return 0 if search_name.blank? || found_name.blank?

    # Normalize names for comparison
    search_normalized = search_name.downcase.gsub(/[^a-z0-9]/, '')
    found_normalized = found_name.downcase.gsub(/[^a-z0-9]/, '')

    # Exact match gets high score
    return 95 if search_normalized == found_normalized

    # If names are very different lengths, likely not a match
    length_diff = (search_normalized.length - found_normalized.length).abs
    return 0 if length_diff > [search_normalized.length, found_normalized.length].min

    # Calculate similarity
    similarity = string_similarity(search_normalized, found_normalized)
    base_score = similarity * 100

    # Be more strict - require high similarity for partial matches
    return 0 if similarity < 0.7

    # Boost score for popular artists (but less aggressively)
    popularity_boost = popularity ? [popularity / 4, 10].min : 0

    # Penalty for very different lengths
    length_penalty = length_diff * 3

    final_score = base_score + popularity_boost - length_penalty
    [final_score, 0].max.round
  end

  # Simple string similarity calculation
  def string_similarity(str1, str2)
    return 0.0 if str1.empty? || str2.empty?
    return 1.0 if str1 == str2

    # Use Levenshtein distance
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1, 0) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i-1] == str2[j-1] ? 0 : 1
        matrix[i][j] = [
          matrix[i-1][j] + 1,     # deletion
          matrix[i][j-1] + 1,     # insertion
          matrix[i-1][j-1] + cost # substitution
        ].min
      end
    end

    distance = matrix[str1.length][str2.length]
    max_length = [str1.length, str2.length].max
    1.0 - (distance.to_f / max_length)
  end

  # ----------------------------------------------------
  # HELPERS & RAW ENDPOINT WRAPPERS
  # ----------------------------------------------------

  # Enhanced artist name sanitization
  def sanitize_artist_name(raw_name)
    return "" if raw_name.blank?

    # Remove country codes in parentheses
    clean = raw_name.gsub(/\s*\([A-Z]{2,3}\)\s*$/, '')

    # Remove common prefixes/suffixes that interfere with search
    clean = clean.gsub(/^(DJ|dj)\s+/i, '')
    clean = clean.gsub(/\s+(live|show|event|performance)$/i, '')

    # Handle multi-artist listings - take first artist only
    clean = clean.split(/\s*[\+&]\s*/).first if clean.include?('+') || clean.include?('&')
    clean = clean.split(/\s*feat\.?\s*/i).first if clean.match?(/feat\.?\s+/i)

    # Clean up extra whitespace
    clean.strip
  end

  # Enhanced artist search with validation
  def _search_artist_with_validation(name, market)
    resp = fetch_with_token(
      "/search",
      q:      name,
      type:   'artist',
      market: market,
      limit:  5  # Get more results to find better matches
    )

    if resp.success? && resp['artists'] && resp['artists']['items'].any?
      # Find the best match from the results
      resp['artists']['items'].each do |artist|
        confidence = calculate_match_confidence(name, artist['name'], artist['popularity'])
        if confidence > 75  # Only return confident matches
          return {
            id: artist['id'],
            name: artist['name'],
            popularity: artist['popularity'] || 0
          }
        end
      end
    end

    nil
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
