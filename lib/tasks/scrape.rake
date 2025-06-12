namespace :scrape do
  desc "Run the enhanced venue scraper"
  task venues: :environment do
    puts '🚀 ENHANCED VENUE SCRAPING WITH DETAILED LOGGING'
    puts '=================================================='

    scraper = UnifiedVenueScraper.new(verbose: true)
    start_time = Time.current

    all_venues = Venue.where.not(website: [nil, ''])
    puts "Found #{all_venues.count} venues with websites"
    puts

    successful_venues = 0
    total_gigs = 0
    failed_venues = []

    all_venues.find_each.with_index do |venue, index|
      puts "\n[#{index + 1}/#{all_venues.count}] Scraping: #{venue.name}"
      puts "  URL: #{venue.website}"

      begin
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }

        gigs = scraper.send(:scrape_venue_optimized, venue_config)
        valid_gigs = scraper.send(:filter_valid_gigs, gigs)

        if valid_gigs.any?
          puts "✅ SUCCESS: #{valid_gigs.count} gigs"
          scraper.send(:save_gigs_to_database, valid_gigs, venue.name)
          successful_venues += 1
          total_gigs += valid_gigs.count

          # Show sample gigs
          puts "📅 Sample gigs:"
          valid_gigs.first(3).each do |gig|
            puts "    ✓ #{gig[:date]} - #{gig[:title]}"
          end
        else
          puts "❌ NO GIGS"
          failed_venues << venue.name
        end
      rescue => e
        puts "❌ ERROR: #{e.message}"
        failed_venues << venue.name
      end

      # Brief pause to be respectful
      sleep(1) unless index == all_venues.count - 1
    end

    duration = Time.current - start_time
    puts "\n🏁 ENHANCED VENUE SCRAPING COMPLETE!"
    puts "⚡ Total time: #{duration.round(2)} seconds"
    puts "🏆 Successful venues: #{successful_venues}/#{all_venues.count}"
    puts "📊 Total gigs found: #{total_gigs}"
    puts "❌ Failed venues: #{failed_venues.count}"

    if failed_venues.any? && failed_venues.count < 20
      puts "\n📋 FAILED VENUES:"
      failed_venues.each_with_index do |venue, i|
        puts "  #{i+1}. #{venue}"
      end
    end
  end

  desc "Run the enhanced gig scraper"
  task gigs: :environment do
    puts "Starting enhanced gig scraping..."
    scraper = EnhancedGigScraper.new
    gigs = scraper.scrape_gigs
    puts "Completed gig scraping. Scraped #{gigs.count} gigs."
  end

  desc "Run all enhanced scrapers"
  task all: :environment do
    puts '🚀 STARTING ALL ENHANCED SCRAPERS WITH DETAILED LOGGING'
    puts '======================================================='
    overall_start = Time.current

    puts "\n🏢 SCRAPING VENUES..."
    puts "="*50

    venue_scraper = UnifiedVenueScraper.new(verbose: true)
    venue_start = Time.current

    all_venues = Venue.where.not(website: [nil, ''])
    puts "Found #{all_venues.count} venues with websites"

    successful_venues = 0
    total_venue_gigs = 0
    failed_venues = []

    all_venues.find_each.with_index do |venue, index|
      puts "\n[#{index + 1}/#{all_venues.count}] Scraping: #{venue.name}"
      puts "  URL: #{venue.website}"

      begin
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: venue_scraper.send(:get_general_selectors)
        }

        gigs = venue_scraper.send(:scrape_venue_optimized, venue_config)
        valid_gigs = venue_scraper.send(:filter_valid_gigs, gigs)

        if valid_gigs.any?
          puts "✅ SUCCESS: #{valid_gigs.count} gigs"
          venue_scraper.send(:save_gigs_to_database, valid_gigs, venue.name)
          successful_venues += 1
          total_venue_gigs += valid_gigs.count
        else
          puts "❌ NO GIGS"
          failed_venues << venue.name
        end
      rescue => e
        puts "❌ ERROR: #{e.message}"
        failed_venues << venue.name
      end

      sleep(1) unless index == all_venues.count - 1
    end

    venue_duration = Time.current - venue_start
    puts "\n✅ VENUE SCRAPING COMPLETE!"
    puts "⚡ Venue scraping time: #{venue_duration.round(2)} seconds"
    puts "🏆 Successful venues: #{successful_venues}/#{all_venues.count}"
    puts "📊 Total venue gigs: #{total_venue_gigs}"

    puts "\n🎵 SCRAPING GIGS..."
    puts "="*50
    gig_scraper = EnhancedGigScraper.new
    gigs = gig_scraper.scrape_gigs
    puts "✅ Completed gig scraping. Scraped #{gigs.count} gigs."

    overall_duration = Time.current - overall_start
    puts "\n🏁 ALL SCRAPING TASKS COMPLETED!"
    puts "="*50
    puts "⚡ Total time: #{overall_duration.round(2)} seconds"
    puts "🏢 Venues: #{successful_venues} successful, #{total_venue_gigs} gigs"
    puts "🎵 Additional gigs: #{gigs.count}"
    puts "📊 Grand total: #{total_venue_gigs + gigs.count} gigs"
  end

  desc "Scrape venue websites for gigs"
  task venue_websites: :environment do
    puts "Starting to scrape venue websites for gigs..."

    # Start with our proven successful venues
    proven_venues = Venue.where("website LIKE ? OR website LIKE ? OR website LIKE ? OR website LIKE ?",
      "%den-atsu%", "%antiknock%", "%milkyway%", "%yokohama-arena%"
    ).limit(4)

    # Add more venues, prioritizing those likely to have gigs
    # First, auto-skip social media and other non-venue sites
    venues_to_skip = Venue.where("website LIKE '%facebook%' OR website LIKE '%instagram%' OR website LIKE '%twitter%' OR website LIKE '%tiktok%' OR website LIKE '%youtube%'")

    puts "Auto-skipping #{venues_to_skip.count} social media venues..."
    venues_to_skip.each do |venue|
      puts "  Skipping social media venue: #{venue.name} (#{venue.website})"
    end

    additional_venues = Venue.where.not(website: [nil, ''])
                             .where.not(id: proven_venues.pluck(:id))  # Exclude proven ones
                             .where("website NOT LIKE '%facebook%'")   # Skip social media
                             .where("website NOT LIKE '%instagram%'")
                             .where("website NOT LIKE '%twitter%'")
                             .where("website NOT LIKE '%tiktok%'")
                             .where("website NOT LIKE '%youtube%'")
                             .where("website NOT LIKE '%blogspot%'")   # Skip blog sites
                             .where("website NOT LIKE '%blog%'")       # Skip blog sites
                             .where("website NOT LIKE '%shop%'")       # Skip shop sites
                             .where("website NOT LIKE '%restaurant%'") # Skip restaurant sites
                             .where("website NOT LIKE '%cafe%'")       # Skip cafe sites (mostly don't have gigs)
                             .where("website NOT LIKE '%hotel%'")      # Skip hotel sites
                             .where("website NOT LIKE '%temple%'")     # Skip temple sites
                             .where("website LIKE 'http%'")            # Only proper URLs
                             # Prioritize domains likely to have gigs
                             .where("website LIKE '%live%' OR website LIKE '%music%' OR website LIKE '%event%' OR website LIKE '%hall%' OR website LIKE '%club%' OR website LIKE '%studio%'")
                             .sample(15)  # Get random sample

    venues = (proven_venues + additional_venues).uniq
    puts "Selected #{venues.count} venues to attempt (#{proven_venues.count} proven + #{additional_venues.count} new)..."

    all_gigs = []
    successful_venues = 0
    failed_venues = []
    venues_to_delete = []
    target_venues = 10

    venues.each_with_index do |venue, index|
      break if successful_venues >= target_venues

      puts "\n" + "="*60
      puts "PROCESSING VENUE #{index + 1}/#{venues.count}: #{venue.name}"
      puts "URL: #{venue.website}"
      puts "="*60

      begin
        # Quick website health check
        if website_accessible?(venue.website)
          scraper = VenueWebsiteScraper.new(venue.website, venue.name)
          gigs = scraper.scrape

          if gigs && gigs.any?
            # Filter out obviously invalid gigs (past dates, closure announcements, etc.)
            valid_gigs = filter_valid_gigs(gigs)

            if valid_gigs.any?
              puts "✅ SUCCESS: Found #{valid_gigs.count} valid gigs for #{venue.name} (#{gigs.count} total extracted)"
              all_gigs.concat(valid_gigs)
              successful_venues += 1
            else
              puts "⚠️  NO VALID GIGS: #{venue.name} - found #{gigs.count} gigs but none were valid/current"
              failed_venues << { venue: venue.name, url: venue.website, reason: "No valid current gigs" }
            end
          else
            puts "⚠️  NO GIGS: #{venue.name} - website accessible but no gigs found"
            failed_venues << { venue: venue.name, url: venue.website, reason: "No gigs found" }
          end
        else
          puts "❌ FAILED: #{venue.name} - website not accessible, marking for deletion"
          venues_to_delete << venue
          failed_venues << { venue: venue.name, url: venue.website, reason: "Website not accessible - will be deleted" }
        end

      rescue => e
        puts "❌ ERROR: #{venue.name} - #{e.message}"
        failed_venues << { venue: venue.name, url: venue.website, reason: e.message }
      end

      # Brief pause between venues to be respectful
      sleep(2) unless index == venues.count - 1
    end

    # Delete venues with dead websites
    if venues_to_delete.any?
      puts "\n🗑️  DELETING VENUES WITH DEAD WEBSITES:"
      venues_to_delete.each do |venue|
        puts "  Deleting venue: #{venue.name} (#{venue.website})"
        venue.destroy
      end
      puts "Deleted #{venues_to_delete.count} venues with dead websites."
    end

    # Save results
    output_file = Rails.root.join('db', 'data', 'venue_website_gigs_expanded.json')
    File.write(output_file, JSON.pretty_generate(all_gigs))

    # Save failure log
    failure_log = Rails.root.join('db', 'data', 'venue_scraping_failures.json')
    File.write(failure_log, JSON.pretty_generate(failed_venues))

    puts "\n" + "="*60
    puts "SCRAPING COMPLETE!"
    puts "="*60
    puts "✅ Successful venues: #{successful_venues}/#{target_venues}"
    puts "📊 Total gigs found: #{all_gigs.count}"
    puts "❌ Failed venues: #{failed_venues.count}"
    puts "🗑️  Deleted venues: #{venues_to_delete.count}"
    puts ""
    puts "📁 Results saved to: #{output_file}"
    puts "📁 Failure log saved to: #{failure_log}"

    if failed_venues.any?
      puts "\n📋 FAILURE SUMMARY:"
      failed_venues.each_with_index do |failure, i|
        puts "#{i+1}. #{failure[:venue]} - #{failure[:reason]}"
      end
    end
  end

  desc "Test proven venues only (debugging)"
  task proven_venues_test: :environment do
    puts "Testing proven venues only..."

    # Test only our 4 proven successful venues
    proven_venues = Venue.where("website LIKE ? OR website LIKE ? OR website LIKE ? OR website LIKE ?",
      "%den-atsu%", "%antiknock%", "%milkyway%", "%yokohama-arena%"
    )

    puts "Found #{proven_venues.count} proven venues to test..."
    proven_venues.each do |venue|
      puts "- #{venue.name}: #{venue.website}"
    end

    all_gigs = []
    successful_venues = 0
    failed_venues = []

    proven_venues.each_with_index do |venue, index|
      puts "\n" + "="*60
      puts "TESTING PROVEN VENUE #{index + 1}/#{proven_venues.count}: #{venue.name}"
      puts "URL: #{venue.website}"
      puts "="*60

      begin
        # Quick website health check
        if website_accessible?(venue.website)
          scraper = VenueWebsiteScraper.new(venue.website, venue.name)
          gigs = scraper.scrape

          if gigs && gigs.any?
            # Filter out obviously invalid gigs (past dates, closure announcements, etc.)
            valid_gigs = filter_valid_gigs(gigs)

            if valid_gigs.any?
              puts "✅ SUCCESS: Found #{valid_gigs.count} valid gigs for #{venue.name} (#{gigs.count} total extracted)"

              # Show detailed gig info for debugging
              valid_gigs.first(3).each_with_index do |gig, i|
                puts "  #{i+1}. #{gig[:title]} - #{gig[:date]} - #{gig[:artists]}"
              end
              if valid_gigs.count > 3
                puts "  ... and #{valid_gigs.count - 3} more gigs"
              end

              all_gigs.concat(valid_gigs)
              successful_venues += 1
            else
              puts "⚠️  NO VALID GIGS: #{venue.name} - found #{gigs.count} gigs but none were valid/current"

              # Show raw gigs for debugging
              puts "  Raw gigs found:"
              gigs.first(3).each_with_index do |gig, i|
                puts "    #{i+1}. #{gig[:title]} - #{gig[:date]} - #{gig[:artists]}"
              end

              failed_venues << { venue: venue.name, url: venue.website, reason: "No valid current gigs", raw_count: gigs.count }
            end
          else
            puts "⚠️  NO GIGS: #{venue.name} - website accessible but no gigs found"
            failed_venues << { venue: venue.name, url: venue.website, reason: "No gigs found" }
          end
        else
          puts "❌ FAILED: #{venue.name} - website not accessible"
          failed_venues << { venue: venue.name, url: venue.website, reason: "Website not accessible" }
        end

      rescue => e
        puts "❌ ERROR: #{venue.name} - #{e.message}"
        puts "  #{e.backtrace.first(3).join('; ')}"
        failed_venues << { venue: venue.name, url: venue.website, reason: e.message }
      end

      # Brief pause between venues
      sleep(2) unless index == proven_venues.count - 1
    end

    # Save results
    output_file = Rails.root.join('db', 'data', 'proven_venues_test.json')
    File.write(output_file, JSON.pretty_generate(all_gigs))

    puts "\n" + "="*60
    puts "PROVEN VENUES TEST COMPLETE!"
    puts "="*60
    puts "✅ Successful venues: #{successful_venues}/#{proven_venues.count}"
    puts "📊 Total gigs found: #{all_gigs.count}"
    puts "❌ Failed venues: #{failed_venues.count}"
    puts ""
    puts "📁 Results saved to: #{output_file}"

    if failed_venues.any?
      puts "\n📋 FAILURE DETAILS:"
      failed_venues.each_with_index do |failure, i|
        puts "#{i+1}. #{failure[:venue]} - #{failure[:reason]}"
        puts "   Raw gigs: #{failure[:raw_count]}" if failure[:raw_count]
      end
    end

    puts "\n🎯 NEXT STEPS:"
    puts "- Successfully working venues: #{successful_venues}"
    puts "- Ready for n+1 incremental scaling once all proven venues work"
  end

  desc "Debug Yokohama Arena specifically"
  task debug_yokohama: :environment do
    puts "Debugging Yokohama Arena specifically..."

    venue = Venue.find_by("website LIKE ?", "%yokohama-arena%")

    if venue.nil?
      puts "❌ Yokohama Arena venue not found!"
      return
    end

    puts "Found venue: #{venue.name} - #{venue.website}"

    begin
      scraper = VenueWebsiteScraper.new(venue.website, venue.name)

      # Navigate to the EVENTS page specifically
      events_url = "#{venue.website.chomp('/')}/event/"
      puts "📍 Testing events page: #{events_url}"

      begin
        scraper.instance_variable_get(:@browser).goto(events_url)
        sleep(5)
      rescue => e
        puts "❌ Failed to load events page: #{e.message}"
        return
      end

      puts "\n🔍 ANALYZING EVENTS PAGE STRUCTURE:"
      doc = Nokogiri::HTML(scraper.instance_variable_get(:@browser).body)

      # Look for table elements
      tables = doc.css('table')
      puts "Found #{tables.count} table elements"

      # Look for table rows
      table_rows = doc.css('table tr')
      puts "Found #{table_rows.count} table rows"

      # Show the first few rows for debugging
      table_rows.first(5).each_with_index do |row, i|
        cells = row.css('td')
        puts "Row #{i+1}: #{cells.count} cells"
        cells.each_with_index do |cell, j|
          text = cell.text.strip
          puts "  Cell #{j+1}: '#{text[0..50]}#{'...' if text.length > 50}'"
        end
        puts ""
      end

      # Test our updated selectors
      puts "\n🧪 TESTING UPDATED SELECTORS:"
      selectors = {
        gigs: 'table tr, .event-row, .schedule-item, .gig, article, .post',
        title: 'td:nth-child(2), .event-name, .title, .gig-title, h3, h2',
        date: 'td:nth-child(1), .event-date, .date, .gig-date, time',
        time: 'td:nth-child(4), .start-time, .gig-time, .time',
        artists: '.artist, .performer, .lineup, .act'
      }

      # Find gig elements using updated selectors
      gig_elements = []
      selectors[:gigs].split(', ').each do |selector|
        elements = doc.css(selector.strip)
        puts "Selector '#{selector}' found #{elements.count} elements"
        gig_elements.concat(elements) if elements.any?
      end

      puts "\nTotal potential elements: #{gig_elements.count}"
      puts "Processing first 3 elements..."

      # Test extraction on table rows
      table_rows_with_data = table_rows.select { |row| row.css('td').count >= 2 }
      puts "\nFound #{table_rows_with_data.count} table rows with multiple cells"

      table_rows_with_data.first(3).each_with_index do |row, i|
        puts "\n=== TABLE ROW #{i+1} ==="
        cells = row.css('td')
        puts "Cells count: #{cells.count}"

        cells.each_with_index do |cell, j|
          puts "  Cell #{j+1}: '#{cell.text.strip}'"
        end

        # Test our extraction
        puts "\n--- TESTING EXTRACTION ---"

        # Simulate extraction
        date_text = cells[0]&.text&.strip
        title_text = cells[1]&.text&.strip
        time_text = cells[3]&.text&.strip

        puts "Raw date: '#{date_text}'"
        puts "Raw title: '#{title_text}'"
        puts "Raw time: '#{time_text}'"

        # Try to parse the date
        if date_text&.match(/(\d{4})\.(\d{2})\.(\d{2})/)
          parsed_date = "#{$1}-#{$2}-#{$3}"
          puts "Parsed date: #{parsed_date}"
        else
          puts "Could not parse date"
        end

        puts "Will be included? #{!!(date_text && title_text && date_text.length > 0 && title_text.length > 5)}"
        puts "--- END EXTRACTION TEST ---\n"
      end

    rescue => e
      puts "❌ Error: #{e.message}"
      puts "  #{e.backtrace.first(3).join('; ')}"
    ensure
      begin
        scraper&.instance_variable_get(:@browser)&.quit
      rescue => e
        puts "  ⚠️  Error closing browser: #{e.message}"
      end
    end
  end

  # Filter out invalid gigs (past dates, closure announcements, etc.)
  def filter_valid_gigs(gigs)
    return [] unless gigs

    today = Date.current
    six_months_ago = today - 6.months
    one_year_from_now = today + 1.year

    gigs.select do |gig|
      next false unless gig[:date]

      begin
        # Fix the date parsing bug - handle both Date objects and strings
        gig_date = gig[:date].is_a?(Date) ? gig[:date] : Date.parse(gig[:date].to_s)
        title = gig[:title]&.downcase || ""

        # Filter out gigs that are clearly not current gigs
        next false if gig_date < six_months_ago || gig_date > one_year_from_now
        next false if title.include?("休み") || title.include?("中止") || title.include?("お知らせ")
        next false if title.include?("closure") || title.include?("closed") || title.include?("cancel")
        next false if title.include?("設営日") || title.include?("撤去日") || title.include?("準備日")  # Setup/teardown days
        next false if title.length < 5  # Too short to be a real gig title

        true
      rescue => e
        puts "    ⚠️  Error filtering gig: #{e.message}"
        false
      end
    end
  end

  # Helper method to check if website is accessible
  def website_accessible?(url)
    begin
      uri = URI.parse(url)
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      # Use a simple HTTP request to check accessibility
      require 'net/http'
      require 'timeout'

      Timeout::timeout(10) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 5

        response = http.request_head(uri.request_uri || '/')

        # Consider 2xx and 3xx status codes as accessible
        response.code.to_i < 400
      end

    rescue => e
      puts "  Website check failed: #{e.message}"
      false
    end
  end

  desc "N+1 incremental venue scaling (systematic approach)"
  task incremental_scaling: :environment do
    puts "🚀 Starting N+1 incremental venue scaling..."

    # Start with proven successful venues (our baseline)
    proven_venues = Venue.where("website LIKE ? OR website LIKE ? OR website LIKE ? OR website LIKE ?",
      "%den-atsu%", "%antiknock%", "%milkyway%", "%yokohama-arena%"
    )

    puts "📊 BASELINE: #{proven_venues.count} proven venues"
    proven_venues.each { |v| puts "  ✅ #{v.name}" }

    # Get candidates for incremental addition (filtered, high-potential venues)
    candidate_venues = Venue.where.not(website: [nil, ''])
                            .where.not(id: proven_venues.pluck(:id))
                            .where("website NOT LIKE '%facebook%'")
                            .where("website NOT LIKE '%instagram%'")
                            .where("website NOT LIKE '%twitter%'")
                            .where("website NOT LIKE '%tiktok%'")
                            .where("website NOT LIKE '%youtube%'")
                            .where("website NOT LIKE '%blogspot%'")
                            .where("website NOT LIKE '%blog%'")
                            .where("website NOT LIKE '%shop%'")
                            .where("website NOT LIKE '%restaurant%'")
                            .where("website NOT LIKE '%cafe%'")
                            .where("website NOT LIKE '%hotel%'")
                            .where("website NOT LIKE '%temple%'")
                            .where("website LIKE 'http%'")
                            # Prioritize venues likely to have gigs
                            .where("name LIKE '%live%' OR name LIKE '%music%' OR name LIKE '%hall%' OR name LIKE '%club%' OR name LIKE '%studio%' OR website LIKE '%live%' OR website LIKE '%music%' OR website LIKE '%event%' OR website LIKE '%hall%' OR website LIKE '%club%' OR website LIKE '%studio%'")
                            .order(:name)

    puts "🎯 CANDIDATES: #{candidate_venues.count} venues available for incremental addition"

    # Current stable set
    current_working_set = proven_venues
    successful_venues = 0
    total_gigs = 0

    # Test baseline first
    puts "\n" + "="*60
    puts "🧪 TESTING BASELINE (PROVEN VENUES)"
    puts "="*60

    baseline_results = test_venue_set(current_working_set)
    successful_venues = baseline_results[:successful]
    total_gigs = baseline_results[:total_gigs]

    puts "📊 BASELINE RESULTS: #{successful_venues}/#{current_working_set.count} venues, #{total_gigs} gigs"

    if successful_venues < current_working_set.count
      puts "⚠️  BASELINE UNSTABLE - fixing proven venues before scaling"
      return
    end

    # Start N+1 incremental addition
    max_additions = 5  # Add up to 5 new venues
    additions_attempted = 0

    candidate_venues.limit(max_additions * 2).each do |candidate| # Try more candidates than we need
      break if additions_attempted >= max_additions

      puts "\n" + "="*60
      puts "🆕 N+1 TEST: Adding #{candidate.name}"
      puts "📍 URL: #{candidate.website}"
      puts "="*60

      # Test with candidate added
      test_set = current_working_set + [candidate]
      results = test_venue_set(test_set)

      if results[:successful] > successful_venues  # We gained a working venue
        puts "✅ SUCCESS: #{candidate.name} added successfully!"
        puts "📈 Improvement: +#{results[:total_gigs] - total_gigs} gigs, +1 venue"

        # Update our working set
        current_working_set = test_set
        successful_venues = results[:successful]
        total_gigs = results[:total_gigs]
        additions_attempted += 1

        puts "🎯 NEW BASELINE: #{successful_venues} venues, #{total_gigs} gigs"

      elsif results[:successful] == successful_venues && results[:total_gigs] >= total_gigs
        puts "🔄 NEUTRAL: #{candidate.name} works but adds no value"

      else
        puts "❌ FAILED: #{candidate.name} breaks stability or reduces performance"
        puts "📉 Impact: #{results[:successful]} venues (-#{successful_venues - results[:successful]}), #{results[:total_gigs]} gigs (-#{total_gigs - results[:total_gigs]})"
      end

      # Brief pause between tests
      sleep(1)
    end

    puts "\n" + "="*60
    puts "🏁 N+1 INCREMENTAL SCALING COMPLETE!"
    puts "="*60
    puts "🚀 Final Results:"
    puts "  📊 Working venues: #{successful_venues}"
    puts "  🎵 Total gigs: #{total_gigs}"
    puts "  ➕ Venues added: #{additions_attempted}"
    puts "  📈 Scaling ratio: #{additions_attempted}/#{max_additions} attempted"

    if additions_attempted == max_additions
      puts "\n🎯 READY FOR NEXT PHASE: Consider increasing max_additions for further scaling"
    elsif additions_attempted == 0
      puts "\n⚠️  NO ADDITIONS: Current baseline may be optimal, or candidate filtering needs adjustment"
    else
      puts "\n✅ STABLE SCALING: Found optimal venue set for this iteration"
    end
  end

  # Helper method to test a set of venues efficiently
  def test_venue_set(venues)
    all_gigs = []
    successful_count = 0

    venues.each do |venue|
      begin
        if website_accessible?(venue.website)
          scraper = VenueWebsiteScraper.new(venue.website, venue.name)
          gigs = scraper.scrape

          if gigs && gigs.any?
            valid_gigs = filter_valid_gigs(gigs)
            if valid_gigs.any?
              all_gigs.concat(valid_gigs)
              successful_count += 1
              puts "  ✅ #{venue.name}: #{valid_gigs.count} gigs"
            else
              puts "  ⚠️  #{venue.name}: found gigs but none valid"
            end
          else
            puts "  ❌ #{venue.name}: no gigs found"
          end
        else
          puts "  💀 #{venue.name}: website not accessible"
        end
      rescue => e
        puts "  🔥 #{venue.name}: error - #{e.message}"
      end
    end

    {
      successful: successful_count,
      total_gigs: all_gigs.count,
      gigs: all_gigs
    }
  end
end
