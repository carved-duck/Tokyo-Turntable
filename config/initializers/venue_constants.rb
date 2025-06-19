# Venue-related constants for the Tokyo Turntable application
module VenueConstants
  # Dynamic venue counts (updated from database)
  def self.total_venue_count
    @total_venue_count ||= Venue.count
  end

  def self.scrapeable_venue_count
    @scrapeable_venue_count ||= Venue.where.not(website: [nil, ''])
                                      .where.not("website ILIKE '%facebook%'")
                                      .where.not("website ILIKE '%instagram%'")
                                      .where.not("website ILIKE '%twitter%'")
                                      .count
  end

  def self.refresh_counts!
    @total_venue_count = nil
    @scrapeable_venue_count = nil
    Rails.logger.info "🔄 Refreshed venue counts: #{total_venue_count} total, #{scrapeable_venue_count} scrapeable"
  end

  # Proven venue configurations (from UnifiedVenueScraper)
  def self.proven_venue_count
    UnifiedVenueScraper::PROVEN_VENUES.count
  end

  # Performance targets
  TARGET_SCRAPE_TIME_MINUTES = 10
  TARGET_VENUES_PER_SECOND = 1.5

  # Parallelism settings based on environment
  def self.max_parallel_venues
    case Rails.env
    when 'production'
      2  # Conservative for production
    when 'test'
      1  # Single-threaded for tests
    else
      6  # Development can handle more
    end
  end

  def self.max_parallel_requests
    case Rails.env
    when 'production'
      12  # Conservative for production
    when 'test'
      5   # Limited for tests
    else
      20  # Development optimized - tested performance
    end
  end
end

# Refresh counts on Rails initialization
Rails.application.config.after_initialize do
  VenueConstants.refresh_counts! if Rails.env.development?
end
