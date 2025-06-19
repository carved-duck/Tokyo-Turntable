class ConfidenceEngine
  # 🛡️ BULLETPROOF CONFIDENCE THRESHOLDS
  CONFIDENCE_LEVELS = {
    venue_location: 0.95,      # 95% - Venue must be verified real location
    venue_active: 0.90,        # 90% - Venue must be currently operating
    gig_exists: 0.85,          # 85% - Gig must be confirmed real event
    band_real: 0.80,           # 80% - Band must be verified real artist
    date_accurate: 0.95,       # 95% - Date must be cross-verified
    time_accurate: 0.85,       # 85% - Time must be reasonably accurate
    price_accurate: 0.75,      # 75% - Price can have some variance
    overall_minimum: 0.85      # 85% - Overall gig confidence minimum
  }.freeze

  def initialize(options = {})
    @verbose = options[:verbose] || false
    @strict_mode = options[:strict_mode] || true
    @verification_cache = {}
  end

  # 🎯 MAIN CONFIDENCE ASSESSMENT
  def assess_gig_confidence(gig)
    puts "🛡️ Assessing confidence for gig at #{gig.venue&.name}" if @verbose

    confidence_scores = {
      venue_location: assess_venue_location_confidence(gig.venue),
      venue_active: assess_venue_active_confidence(gig.venue),
      gig_exists: assess_gig_existence_confidence(gig),
      band_real: assess_band_reality_confidence(gig.bands),
      date_accurate: assess_date_accuracy_confidence(gig),
      time_accurate: assess_time_accuracy_confidence(gig),
      price_accurate: assess_price_accuracy_confidence(gig)
    }

    overall_confidence = calculate_overall_confidence(confidence_scores)

    result = {
      gig_id: gig.id,
      venue_name: gig.venue&.name,
      overall_confidence: overall_confidence,
      confidence_scores: confidence_scores,
      meets_threshold: overall_confidence >= CONFIDENCE_LEVELS[:overall_minimum],
      risk_factors: identify_risk_factors(confidence_scores),
      verification_status: determine_verification_status(overall_confidence)
    }

    puts "🎯 Overall confidence: #{(overall_confidence * 100).round(1)}%" if @verbose
    puts "✅ Meets threshold: #{result[:meets_threshold]}" if @verbose

    result
  end

  # 🏢 VENUE LOCATION CONFIDENCE
  def assess_venue_location_confidence(venue)
    return 0.0 unless venue

    score = 0.5 # Base score

    # Has real address (not just "Tokyo")
    if venue.address.present? && venue.address.length > 10 && !venue.address.match?(/^(Tokyo|Japan)$/i)
      score += 0.2
    end

    # Has verified website
    if venue.website.present? && venue.website.match?(/^https?:\/\//)
      score += 0.2
    end

    # Has neighborhood info
    if venue.neighborhood.present? && venue.neighborhood != 'Tokyo'
      score += 0.1
    end

    # Cross-reference with known venue databases
    if verified_venue_exists?(venue)
      score += 0.2
    end

    # Penalty for suspicious patterns
    score -= 0.3 if venue.name.match?(/test|fake|dummy|example/i)
    score -= 0.2 if venue.address.match?(/test|fake|dummy/i)

    [[score, 0.0].max, 1.0].min
  end

  # 🎪 VENUE ACTIVE STATUS CONFIDENCE
  def assess_venue_active_confidence(venue)
    return 0.0 unless venue

    score = 0.5 # Base score

    # Recent gig activity
    recent_gigs = venue.gigs.where('date >= ?', 30.days.ago).count
    if recent_gigs > 0
      score += 0.3
    elsif recent_gigs == 0 && venue.gigs.where('date >= ?', 90.days.ago).count > 0
      score += 0.1
    end

    # Website accessibility
    if venue.website.present?
      website_status = check_website_accessibility(venue.website)
      case website_status
      when :active
        score += 0.2
      when :redirect
        score += 0.1
      when :dead
        score -= 0.3
      end
    end

    # Social media presence (if available)
    if has_active_social_media?(venue)
      score += 0.1
    end

    [[score, 0.0].max, 1.0].min
  end

  # 🎵 GIG EXISTENCE CONFIDENCE
  def assess_gig_existence_confidence(gig)
    score = 0.5 # Base score

    # Has reasonable date (not too far in future, not in past)
    if gig.date.present?
      days_from_now = (gig.date - Date.current).to_i
      if days_from_now >= 0 && days_from_now <= 365
        score += 0.2
      elsif days_from_now < 0
        score -= 0.4 # Past events are suspicious for new data
      end
    end

    # Has reasonable time
    if gig.start_time.present? && gig.start_time.match?(/\d{1,2}:\d{2}/)
      hour = gig.start_time.split(':')[0].to_i
      if hour >= 12 && hour <= 23 # Reasonable gig hours
        score += 0.1
      end
    end

    # Has bands associated
    if gig.bands.any?
      score += 0.2
    else
      score -= 0.1
    end

    # Cross-verification with venue's typical schedule
    if fits_venue_pattern?(gig)
      score += 0.1
    end

    [[score, 0.0].max, 1.0].min
  end

  # 🎤 BAND REALITY CONFIDENCE
  def assess_band_reality_confidence(bands)
    return 0.0 if bands.empty?

    total_confidence = 0.0
    bands.each do |band|
      band_confidence = assess_single_band_confidence(band)
      total_confidence += band_confidence
    end

    total_confidence / bands.count
  end

  def assess_single_band_confidence(band)
    score = 0.5 # Base score

    # Name quality checks
    if band.name.present?
      # Good length
      if band.name.length >= 2 && band.name.length <= 50
        score += 0.1
      end

      # Contains letters (not just numbers/symbols)
      if band.name.match?(/[a-zA-Zひらがなカタカナ漢字]/)
        score += 0.1
      end

      # Not obviously fake
      unless band.name.match?(/^\d+$|^test|^fake|^dummy/i)
        score += 0.1
      end
    end

    # Genre classification confidence
    if band.genre != 'Unknown'
      score += 0.1
    end

    # Has multiple gigs (suggests real artist)
    gig_count = band.gigs.count
    if gig_count > 1
      score += 0.1
    elsif gig_count > 5
      score += 0.2
    end

    # External verification (Spotify, MusicBrainz, etc.)
    if verified_artist_exists?(band)
      score += 0.2
    end

    [[score, 0.0].max, 1.0].min
  end

  # 📅 DATE ACCURACY CONFIDENCE
  def assess_date_accuracy_confidence(gig)
    return 0.0 unless gig.date.present?

    score = 0.8 # High base score for dates

    # Date is in reasonable future
    days_from_now = (gig.date - Date.current).to_i
    if days_from_now < 0
      score = 0.2 # Very low confidence for past dates
    elsif days_from_now > 365
      score -= 0.3 # Lower confidence for far future
    end

    # Date format consistency
    if gig.date.is_a?(Date)
      score += 0.1
    end

    score
  end

  # ⏰ TIME ACCURACY CONFIDENCE
  def assess_time_accuracy_confidence(gig)
    score = 0.6 # Base score

    if gig.start_time.present? && gig.start_time.match?(/^\d{1,2}:\d{2}$/)
      score += 0.2

      # Reasonable gig hours
      hour = gig.start_time.split(':')[0].to_i
      if hour >= 18 && hour <= 23
        score += 0.1
      elsif hour >= 12 && hour <= 17
        score += 0.05
      end
    end

    if gig.open_time.present? && gig.open_time != gig.start_time
      score += 0.1
    end

    score
  end

  # 💰 PRICE ACCURACY CONFIDENCE
  def assess_price_accuracy_confidence(gig)
    score = 0.7 # Base score (price is less critical)

    if gig.price.present?
      price_str = gig.price.to_s

      # Has numeric price
      if price_str.match?(/\d+/)
        score += 0.1

        # Reasonable price range for Tokyo gigs
        price_num = price_str.scan(/\d+/).first.to_i
        if price_num >= 1000 && price_num <= 10000
          score += 0.1
        elsif price_num > 0 && price_num < 1000
          score += 0.05
        end
      end

      # Not obviously placeholder
      unless price_str.match?(/tbd|tba|unknown|free|0/i)
        score += 0.1
      end
    end

    score
  end

  # 🎯 OVERALL CONFIDENCE CALCULATION
  def calculate_overall_confidence(scores)
    # Weighted average with critical factors having more weight
    weights = {
      venue_location: 0.25,    # Critical - wrong venue = disaster
      venue_active: 0.20,      # Critical - closed venue = disaster
      gig_exists: 0.20,        # Critical - fake gig = disaster
      band_real: 0.15,         # Important - but less critical
      date_accurate: 0.10,     # Important - but can be verified
      time_accurate: 0.05,     # Nice to have
      price_accurate: 0.05     # Nice to have
    }

    weighted_sum = scores.sum { |factor, score| weights[factor] * score }
    weighted_sum
  end

  # ⚠️ RISK FACTOR IDENTIFICATION
  def identify_risk_factors(scores)
    risks = []

    scores.each do |factor, score|
      threshold = CONFIDENCE_LEVELS[factor]
      if score < threshold
        risk_level = case (threshold - score)
        when 0.0..0.1 then 'LOW'
        when 0.1..0.3 then 'MEDIUM'
        else 'HIGH'
        end

        risks << {
          factor: factor,
          score: score,
          threshold: threshold,
          risk_level: risk_level,
          description: get_risk_description(factor, score)
        }
      end
    end

    risks.sort_by { |risk| risk[:threshold] - risk[:score] }.reverse
  end

  # 🏆 VERIFICATION STATUS
  def determine_verification_status(confidence)
    case confidence
    when 0.95..1.0
      'VERIFIED' # Show with full confidence
    when 0.85..0.94
      'TRUSTED' # Show with minor disclaimer
    when 0.70..0.84
      'CAUTION' # Show with clear warnings
    when 0.50..0.69
      'UNVERIFIED' # Don't show to users
    else
      'REJECTED' # Remove from database
    end
  end

  # 🔍 HELPER METHODS
  private

  def verified_venue_exists?(venue)
    # Check against known venue databases, Google Places, etc.
    # This would integrate with external APIs
    cache_key = "venue_verified_#{venue.id}"
    return @verification_cache[cache_key] if @verification_cache.key?(cache_key)

    # Placeholder for real verification logic
    verified = venue.website.present? && venue.address.length > 15
    @verification_cache[cache_key] = verified
    verified
  end

  def check_website_accessibility(url)
    return :unknown unless url.present?

    cache_key = "website_#{url}"
    return @verification_cache[cache_key] if @verification_cache.key?(cache_key)

    begin
      # This would make actual HTTP requests
      # For now, basic URL validation
      if url.match?(/^https?:\/\/[^\s]+\.[^\s]+/)
        @verification_cache[cache_key] = :active
        :active
      else
        @verification_cache[cache_key] = :dead
        :dead
      end
    rescue
      @verification_cache[cache_key] = :dead
      :dead
    end
  end

  def has_active_social_media?(venue)
    # Check for active social media presence
    # This would integrate with social media APIs
    false # Placeholder
  end

  def fits_venue_pattern?(gig)
    # Check if gig fits the venue's typical schedule pattern
    venue = gig.venue
    return true unless venue

    # Analyze venue's historical patterns
    typical_days = venue.gigs.group(:date).count.keys.map(&:wday)
    gig_day = gig.date.wday

    typical_days.include?(gig_day) || typical_days.empty?
  end

  def verified_artist_exists?(band)
    # Check against Spotify, MusicBrainz, Last.fm, etc.
    cache_key = "artist_verified_#{band.id}"
    return @verification_cache[cache_key] if @verification_cache.key?(cache_key)

    # Placeholder for real artist verification
    verified = band.genre != 'Unknown' && band.gigs.count > 1
    @verification_cache[cache_key] = verified
    verified
  end

  def get_risk_description(factor, score)
    case factor
    when :venue_location
      "Venue location not fully verified (#{(score * 100).round(1)}%)"
    when :venue_active
      "Venue operational status uncertain (#{(score * 100).round(1)}%)"
    when :gig_exists
      "Gig existence not confirmed (#{(score * 100).round(1)}%)"
    when :band_real
      "Artist authenticity questionable (#{(score * 100).round(1)}%)"
    when :date_accurate
      "Date accuracy uncertain (#{(score * 100).round(1)}%)"
    when :time_accurate
      "Time information incomplete (#{(score * 100).round(1)}%)"
    when :price_accurate
      "Price information unreliable (#{(score * 100).round(1)}%)"
    else
      "Unknown risk factor"
    end
  end
end
