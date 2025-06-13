class ResponsibleScraperConfig
  class << self
    # 🛡️ RESPONSIBLE SCRAPING CONFIGURATION
    # Addresses rate limiting, legal compliance, and ethical scraping practices

    def rate_limiting_config
      {
        # Delays between requests (in seconds)
        between_venues: 3.0,           # 3 seconds between venues (was 1-2)
        between_requests: 1.5,         # 1.5 seconds between page requests
        after_errors: 10.0,            # 10 seconds after any error
        browser_page_load: 5.0,        # 5 seconds for page loads

        # Random delays to appear more human-like
        random_delay_range: (1..3),    # Add 1-3 random seconds

        # Maximum requests per session
        max_venues_per_run: 50,        # Limit to 50 venues per run (was unlimited)
        max_retries_per_venue: 2,      # Max 2 retries per venue

        # Cool-down periods
        daily_limit: 100,              # Max 100 venues per day
        weekly_limit: 300,             # Max 300 venues per week
      }
    end

    def user_agent_rotation
      [
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15'
      ]
    end

    def get_random_user_agent
      user_agent_rotation.sample
    end

    def respectful_delay(venue_name = nil)
      config = rate_limiting_config
      base_delay = config[:between_venues]
      random_extra = rand(config[:random_delay_range])

      total_delay = base_delay + random_extra

      puts "    ⏱️  Respectful delay: #{total_delay}s (being nice to #{venue_name})" if venue_name
      sleep(total_delay)
    end

    def should_continue_scraping?(venues_scraped_today)
      config = rate_limiting_config

      if venues_scraped_today >= config[:daily_limit]
        puts "🛑 Daily limit reached (#{config[:daily_limit]} venues). Stopping for today."
        return false
      end

      true
    end

    def legal_compliance_notice
      puts "📋 LEGAL & ETHICAL SCRAPING NOTICE"
      puts "=" * 50
      puts "✅ Rate limiting: 3s+ delays between venues"
      puts "✅ Respectful robots.txt checking"
      puts "✅ User-agent rotation for natural traffic"
      puts "✅ Error handling to avoid retries"
      puts "✅ Public schedule data only (no private areas)"
      puts "✅ No user account required content"
      puts "✅ Weekly scheduling to minimize impact"
      puts ""
      puts "📄 Legal Notes:"
      puts "• Scraping publicly available schedule data"
      puts "• Educational/personal project use"
      puts "• No commercial use or resale"
      puts "• Respecting site terms where possible"
      puts "• Can stop immediately if requested"
      puts "=" * 50
    end

    def check_robots_txt(url)
      begin
        uri = URI.parse(url)
        robots_url = "#{uri.scheme}://#{uri.host}/robots.txt"

        response = HTTParty.get(robots_url, timeout: 5)
        if response.success?
          robots_content = response.body.downcase

          # Check if our scraping is explicitly disallowed
          if robots_content.include?('disallow: /') && robots_content.include?('user-agent: *')
            puts "    🤖 robots.txt: Site prefers no crawling"
            return :discouraged
          elsif robots_content.include?('crawl-delay')
            puts "    🤖 robots.txt: Crawl delay requested"
            return :delay_requested
          else
            puts "    🤖 robots.txt: No restrictions found"
            return :allowed
          end
        end
      rescue => e
        # If we can't check robots.txt, proceed cautiously
        puts "    🤖 robots.txt: Could not check (proceeding cautiously)"
      end

      :unknown
    end

    def enhanced_error_handling(error, venue_name, url)
      case error.message
      when /blocked/i, /forbidden/i, /403/
        puts "    🚫 Access blocked - respecting site's wishes"
        return :blocked
      when /rate limit/i, /too many requests/i, /429/
        puts "    ⏳ Rate limited - increasing delays"
        sleep(30) # Longer delay for rate limiting
        return :rate_limited
      when /timeout/i
        puts "    ⏱️  Timeout - site may be slow"
        return :timeout
      else
        puts "    ❌ General error: #{error.message}"
        return :general_error
      end
    end

    def weekly_scraping_schedule
      {
        # Run once per week on Sundays at 2 AM (low traffic time)
        cron_schedule: "0 2 * * 0",  # Sunday at 2 AM
        description: "Weekly scraping - Sundays at 2 AM",

        # Batch configuration for weekly runs
        venues_per_weekly_run: 200,   # Reasonable weekly batch
        max_duration_hours: 3,        # Stop after 3 hours regardless

        # Backup schedule if main run fails
        backup_cron: "0 14 * * 0",    # Sunday at 2 PM as backup
      }
    end

    def create_scraping_session_log
      session_data = {
        session_id: SecureRandom.uuid,
        started_at: Time.current,
        rate_limiting: rate_limiting_config,
        legal_compliance: "Educational/personal use only",
        user_agent: get_random_user_agent,
        venues_planned: nil,
        venues_completed: 0,
        errors_encountered: [],
        respectful_delays_total: 0
      }

      log_file = Rails.root.join('tmp', 'scraping_session.json')
      File.write(log_file, JSON.pretty_generate(session_data))

      session_data
    end

    def update_session_log(updates)
      log_file = Rails.root.join('tmp', 'scraping_session.json')
      if File.exist?(log_file)
        session_data = JSON.parse(File.read(log_file))
        session_data.merge!(updates)
        File.write(log_file, JSON.pretty_generate(session_data))
      end
    end
  end
end
