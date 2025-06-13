class VenueScrapingJob < ApplicationJob
  queue_as :default

  def perform(options = {})
    # Extract options with defaults
    mode = options['mode'] || 'responsible_weekly'
    max_venues = options['max_venues'] || 200
    max_duration_hours = options['max_duration_hours'] || 3
    rate_limiting = options['rate_limiting'] || true
    respect_robots_txt = options['respect_robots_txt'] || true
    verbose = options['verbose'] || false

    Rails.logger.info "🤖 Starting #{mode} venue scraping job"

    # Show legal compliance notice
    ResponsibleScraperConfig.legal_compliance_notice if verbose

    # Create session log for transparency
    session_log = ResponsibleScraperConfig.create_scraping_session_log
    session_log[:venues_planned] = max_venues
    ResponsibleScraperConfig.update_session_log(session_log)

    # Set start time for duration checking
    start_time = Time.current
    max_end_time = start_time + max_duration_hours.hours

    # Initialize scraper with environment-appropriate configuration
    is_production = Rails.env.production? || Rails.env.staging?

    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: is_production ? 1 : 2,  # Conservative in production
      verbose: verbose,
      responsible_mode: is_production ? true : rate_limiting,  # Always responsible in production
      rate_limiting: is_production ? true : rate_limiting,
      respect_robots: is_production ? true : respect_robots_txt,
      user_agent: is_production ? ResponsibleScraperConfig.get_random_user_agent : nil
    )

    if is_production
      Rails.logger.info "🛡️ Production environment: Using responsible scraping mode"
    else
      Rails.logger.info "🏎️ Development environment: Using configured scraping mode"
    end

    case mode
    when 'responsible_weekly'
      result = perform_weekly_scraping(scraper, max_venues, max_end_time, session_log)
    when 'backup_weekly'
      result = perform_backup_scraping(scraper, max_venues, max_end_time, session_log)
    when 'development_test'
      result = perform_development_test(scraper, max_venues, max_end_time, session_log)
    else
      result = perform_legacy_scraping(scraper, session_log)
    end

    # Update final session log
    session_log[:completed_at] = Time.current
    session_log[:duration_minutes] = ((Time.current - start_time) / 1.minute).round(2)
    session_log[:result] = result
    ResponsibleScraperConfig.update_session_log(session_log)

    Rails.logger.info "✅ Scraping job completed in #{session_log[:duration_minutes]} minutes"
    result

  rescue => e
    Rails.logger.error "❌ Venue scraping job failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    # Log error in session
    ResponsibleScraperConfig.update_session_log({
      error: e.message,
      failed_at: Time.current
    })

    return { success: false, error: e.message }
  end

  private

  def perform_weekly_scraping(scraper, max_venues, max_end_time, session_log)
    Rails.logger.info "🗓️ Weekly responsible scraping: max #{max_venues} venues"

    total_gigs = 0
    venues_processed = 0
    successful_venues = 0

    # Get candidate venues in batches
    candidate_venues = get_candidate_venues_for_weekly_run(max_venues)

    candidate_venues.each_with_index do |venue, index|
      # Check time limit
      if Time.current >= max_end_time
        Rails.logger.info "⏰ Time limit reached (#{max_end_time}). Stopping gracefully."
        break
      end

      # Check daily venue limit
      unless ResponsibleScraperConfig.should_continue_scraping?(venues_processed)
        break
      end

      Rails.logger.info "[#{index + 1}/#{candidate_venues.length}] Processing: #{venue.name}"

      # Check robots.txt if requested
      robots_status = ResponsibleScraperConfig.check_robots_txt(venue.website)
      if robots_status == :discouraged
        Rails.logger.info "    🤖 Skipping due to robots.txt"
        next
      end

      begin
        # Respectful delay before scraping
        ResponsibleScraperConfig.respectful_delay(venue.name) if index > 0

        # Scrape venue with responsible configuration
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }

        gigs = scrape_venue_responsibly(scraper, venue_config)

        if gigs.any?
          successful_venues += 1
          total_gigs += gigs.length
          Rails.logger.info "    ✅ Found #{gigs.length} gigs"
        else
          Rails.logger.info "    ❌ No gigs found"
        end

        venues_processed += 1

      rescue => e
        error_type = ResponsibleScraperConfig.enhanced_error_handling(e, venue.name, venue.website)
        session_log[:errors_encountered] << {
          venue: venue.name,
          error: e.message,
          type: error_type,
          timestamp: Time.current
        }

        # Stop if we're being blocked
        if error_type == :blocked
          Rails.logger.info "🛑 Stopping scraping due to blocking detection"
          break
        end
      end
    end

    {
      success: true,
      mode: 'responsible_weekly',
      venues_processed: venues_processed,
      successful_venues: successful_venues,
      total_gigs: total_gigs,
      duration_minutes: session_log[:duration_minutes]
    }
  end

  def perform_backup_scraping(scraper, max_venues, max_end_time, session_log)
    # Check if primary run already succeeded today
    if primary_run_succeeded_today?
      Rails.logger.info "🔄 Primary run already succeeded today. Skipping backup."
      return { success: true, skipped: true, reason: "Primary run succeeded" }
    end

    Rails.logger.info "🔄 Backup scraping: smaller batch of #{max_venues} venues"

    # Use proven venues for backup run (more reliable)
    proven_venues = UnifiedVenueScraper::PROVEN_VENUES.first(max_venues)

    total_gigs = 0
    successful_venues = 0

    proven_venues.each_with_index do |venue_config, index|
      if Time.current >= max_end_time
        break
      end

      ResponsibleScraperConfig.respectful_delay(venue_config[:name]) if index > 0

      begin
        gigs = scrape_venue_responsibly(scraper, venue_config)
        if gigs.any?
          successful_venues += 1
          total_gigs += gigs.length
        end
      rescue => e
        Rails.logger.error "Backup scraping error for #{venue_config[:name]}: #{e.message}"
      end
    end

    {
      success: true,
      mode: 'backup_weekly',
      successful_venues: successful_venues,
      total_gigs: total_gigs
    }
  end

  def perform_development_test(scraper, max_venues, max_end_time, session_log)
    Rails.logger.info "🧪 Development test: #{max_venues} venues with full logging"

    # Use proven venues for development testing
    test_venues = UnifiedVenueScraper::PROVEN_VENUES.first(max_venues)

    results = []

    test_venues.each do |venue_config|
      ResponsibleScraperConfig.respectful_delay(venue_config[:name])

      begin
        gigs = scrape_venue_responsibly(scraper, venue_config)
        results << {
          venue: venue_config[:name],
          gigs_found: gigs.length,
          success: gigs.any?
        }
      rescue => e
        results << {
          venue: venue_config[:name],
          error: e.message,
          success: false
        }
      end
    end

    {
      success: true,
      mode: 'development_test',
      results: results,
      total_venues: results.length,
      successful_venues: results.count { |r| r[:success] }
    }
  end

  def perform_legacy_scraping(scraper, session_log)
    # Fallback to original scraping with rate limiting
    Rails.logger.info "🔄 Legacy scraping mode with rate limiting"

    ResponsibleScraperConfig.respectful_delay
    proven_result = scraper.test_proven_venues_parallel(verbose: false)

    {
      success: true,
      mode: 'legacy',
      successful_venues: proven_result[:successful_venues],
      total_gigs: proven_result[:total_gigs]
    }
  end

    def scrape_venue_responsibly(scraper, venue_config)
    # 🛡️ ACTUAL RESPONSIBLE SCRAPING - Connected to UnifiedVenueScraper

    # Apply responsible rate limiting
    sleep(ResponsibleScraperConfig.rate_limiting_config[:between_requests])

    # Use random user agent for each venue
    # Note: This would require UnifiedVenueScraper modification to accept user agents

    begin
      # Call the actual scraper with responsible settings
      # Using existing optimized scraping method but with built-in delays
      gigs = scraper.scrape_venue_optimized(venue_config)

      # Filter gigs for validity (like the main scraper does)
      if gigs&.any?
        valid_gigs = scraper.filter_valid_gigs(gigs)
        Rails.logger.info "    🔧 Filtered: #{valid_gigs.length}/#{gigs.length} gigs valid"

        # Save valid gigs to database
        if valid_gigs.any?
          db_result = scraper.send(:save_gigs_to_database, valid_gigs, venue_config[:name])
          Rails.logger.info "    💾 Database: #{db_result[:saved]} saved, #{db_result[:skipped]} skipped"

          # Additional respectful delay after successful scraping
          sleep(0.5)

          return valid_gigs
        else
          Rails.logger.info "    ⚠️ No valid current gigs found"
          return []
        end
      else
        Rails.logger.info "    ❌ No gigs found"
        return []
      end

    rescue => e
      # Enhanced error handling with responsible behavior
      error_type = ResponsibleScraperConfig.enhanced_error_handling(e, venue_config[:name], venue_config[:url])

      case error_type
      when :blocked
        Rails.logger.error "    🚫 Venue blocked us - adding to blacklist"
        scraper.add_to_blacklist(venue_config[:name], "Blocked during responsible scraping")
        raise e  # Re-raise to stop the job
      when :rate_limited
        Rails.logger.warn "    ⏳ Rate limited - already applied 30s delay"
        return []  # Return empty but don't fail
      when :timeout
        Rails.logger.warn "    ⏱️ Timeout - venue may be slow"
        return []  # Return empty but don't fail
      else
        Rails.logger.error "    ❌ Error: #{e.message}"
        return []  # Return empty but don't fail
      end
    end
  end

  def get_candidate_venues_for_weekly_run(max_venues)
    # Get venues that haven't been scraped recently
    Venue.where.not(website: [nil, ''])
         .where("website NOT LIKE '%facebook%'")
         .where("website NOT LIKE '%instagram%'")
         .where("website NOT LIKE '%twitter%'")
         .limit(max_venues)
         .order(:updated_at)  # Prioritize venues not updated recently
  end

  def primary_run_succeeded_today?
    # Check if there's a successful scraping session from today
    log_file = Rails.root.join('tmp', 'scraping_session.json')
    return false unless File.exist?(log_file)

    begin
      session_data = JSON.parse(File.read(log_file))
      last_run = DateTime.parse(session_data['started_at'])
      last_run.to_date == Date.current && session_data['result']&.fetch('success', false)
    rescue
      false
    end
  end
end
