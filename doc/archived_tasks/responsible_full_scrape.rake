namespace :scrape do
  desc "Responsible full scrape of all venues with safety controls"
  task :full_responsible, [:batch_size, :delay_override] => :environment do |t, args|
    batch_size = (args[:batch_size] || 100).to_i
    delay_override = args[:delay_override]&.to_f

    puts "🚀 RESPONSIBLE FULL SCRAPE - ALL VENUES"
    puts "=" * 60
    puts "📊 Estimated venues: ~#{Venue.count}"
    puts "🔢 Batch size: #{batch_size} venues per batch"
    puts "⏱️  Delay override: #{delay_override || 'default (3-6s)'}"
    puts "=" * 60

    # Show legal compliance notice
    ResponsibleScraperConfig.legal_compliance_notice

    # Get total venue count
    total_venues = Venue.where.not(website: [nil, ''])
                        .where("website NOT LIKE '%facebook%'")
                        .where("website NOT LIKE '%instagram%'")
                        .where("website NOT LIKE '%twitter%'")
                        .count

    puts "\n📈 FULL SCRAPE PLAN"
    puts "-" * 30
    puts "Total venues to scrape: #{total_venues}"
    puts "Batch size: #{batch_size}"
    puts "Number of batches: #{(total_venues.to_f / batch_size).ceil}"
    puts "Estimated time per batch: #{batch_size * 45 / 60} minutes"
    puts "Total estimated time: #{(total_venues * 45 / 60 / 60).round(1)} hours"
    puts ""

    print "🤔 Continue with full scrape? (y/N): "
    response = STDIN.gets.chomp.downcase

    unless response == 'y' || response == 'yes'
      puts "❌ Full scrape cancelled."
      exit
    end

    puts "\n🚀 Starting responsible full scrape..."

    # Initialize tracking
    start_time = Time.current
    total_processed = 0
    total_successful = 0
    total_gigs = 0
    batch_number = 0
    session_log = ResponsibleScraperConfig.create_scraping_session_log

    # Process venues in batches
    Venue.where.not(website: [nil, ''])
         .where("website NOT LIKE '%facebook%'")
         .where("website NOT LIKE '%instagram%'")
         .where("website NOT LIKE '%twitter%'")
         .find_in_batches(batch_size: batch_size) do |venue_batch|

      batch_number += 1
      batch_start = Time.current

      puts "\n" + "🔄 BATCH #{batch_number}/#{(total_venues.to_f / batch_size).ceil}".center(60, "=")
      puts "Processing venues #{total_processed + 1}-#{total_processed + venue_batch.size}"
      puts "=" * 60

      # Process batch with VenueScrapingJob
      batch_result = process_venue_batch_responsibly(venue_batch, delay_override, session_log)

      # Update counters
      total_processed += venue_batch.size
      total_successful += batch_result[:successful_venues]
      total_gigs += batch_result[:total_gigs]

      # Show batch results
      batch_duration = ((Time.current - batch_start) / 1.minute).round(1)
      puts "\n📊 BATCH #{batch_number} COMPLETE"
      puts "-" * 30
      puts "Processed: #{venue_batch.size} venues"
      puts "Successful: #{batch_result[:successful_venues]} venues"
      puts "Gigs found: #{batch_result[:total_gigs]}"
      puts "Duration: #{batch_duration} minutes"
      puts "Success rate: #{(batch_result[:successful_venues].to_f / venue_batch.size * 100).round(1)}%"

      # Overall progress
      overall_duration = ((Time.current - start_time) / 1.hour).round(1)
      progress_percent = (total_processed.to_f / total_venues * 100).round(1)

      puts "\n🎯 OVERALL PROGRESS"
      puts "-" * 30
      puts "Progress: #{total_processed}/#{total_venues} (#{progress_percent}%)"
      puts "Total successful: #{total_successful} venues"
      puts "Total gigs: #{total_gigs}"
      puts "Overall duration: #{overall_duration} hours"
      puts "Success rate: #{(total_successful.to_f / total_processed * 100).round(1)}%"

      # Inter-batch delay (longer pause between batches)
      if batch_number < (total_venues.to_f / batch_size).ceil
        inter_batch_delay = 30 # 30 seconds between batches
        puts "\n⏸️  Inter-batch pause: #{inter_batch_delay} seconds..."
        sleep(inter_batch_delay)
      end

      # Safety check - stop if success rate is too low
      if total_processed >= 50 && (total_successful.to_f / total_processed) < 0.10
        puts "\n🛑 SAFETY STOP: Success rate below 10%. May be getting blocked."
        puts "Consider stopping and checking what's happening."
        print "Continue anyway? (y/N): "
        response = STDIN.gets.chomp.downcase
        unless response == 'y' || response == 'yes'
          puts "❌ Full scrape stopped for safety."
          break
        end
      end
    end

    # Final results
    total_duration = ((Time.current - start_time) / 1.hour).round(2)

    puts "\n" + "🎉 FULL SCRAPE COMPLETE".center(60, "=")
    puts "Total venues processed: #{total_processed}"
    puts "Total successful venues: #{total_successful}"
    puts "Total gigs found: #{total_gigs}"
    puts "Total duration: #{total_duration} hours"
    puts "Overall success rate: #{(total_successful.to_f / total_processed * 100).round(1)}%"
    puts "Average gigs per successful venue: #{(total_gigs.to_f / total_successful).round(1)}" if total_successful > 0
    puts "=" * 60

    # Update session log
    ResponsibleScraperConfig.update_session_log({
      completed_at: Time.current,
      total_venues_processed: total_processed,
      total_successful_venues: total_successful,
      total_gigs_found: total_gigs,
      duration_hours: total_duration,
      success_rate: (total_successful.to_f / total_processed * 100).round(1)
    })

    puts "\n✅ Session logged to tmp/scraping_session.json"
    puts "🎯 Use this data to analyze venue patterns and improve targeting!"
  end

  desc "Quick responsible test of proven venues"
  task :test_proven_responsible => :environment do
    puts "🧪 RESPONSIBLE PROVEN VENUES TEST"
    puts "=" * 50

    # Create responsible scraper
    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 1,
      verbose: true,
      responsible_mode: true,
      rate_limiting: true,
      respect_robots: true,
      user_agent: ResponsibleScraperConfig.get_random_user_agent
    )

    proven_venues = UnifiedVenueScraper::PROVEN_VENUES
    total_gigs = 0
    successful_venues = 0

    proven_venues.each_with_index do |venue_config, index|
      puts "\n[#{index + 1}/#{proven_venues.length}] Testing: #{venue_config[:name]}"

      # Respectful delay
      ResponsibleScraperConfig.respectful_delay(venue_config[:name]) if index > 0

      begin
        gigs = scraper.scrape_venue_optimized(venue_config)

        if gigs&.any?
          valid_gigs = scraper.filter_valid_gigs(gigs)
          if valid_gigs.any?
            db_result = scraper.send(:save_gigs_to_database, valid_gigs, venue_config[:name])
            puts "  ✅ Success: #{valid_gigs.length} gigs (#{db_result[:saved]} saved, #{db_result[:skipped]} skipped)"
            total_gigs += valid_gigs.length
            successful_venues += 1
          else
            puts "  ⚠️  Found gigs but none were valid/current"
          end
        else
          puts "  ❌ No gigs found"
        end
      rescue => e
        puts "  ❌ Error: #{e.message}"
      end
    end

    puts "\n📊 PROVEN VENUES TEST COMPLETE"
    puts "-" * 30
    puts "Successful venues: #{successful_venues}/#{proven_venues.length}"
    puts "Total gigs: #{total_gigs}"
    puts "Success rate: #{(successful_venues.to_f / proven_venues.length * 100).round(1)}%"
  end

  private

  def process_venue_batch_responsibly(venues, delay_override, session_log)
    # Create responsible scraper for this batch
    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 1,
      verbose: true,
      responsible_mode: true,
      rate_limiting: true,
      respect_robots: true,
      user_agent: ResponsibleScraperConfig.get_random_user_agent
    )

    batch_gigs = 0
    batch_successful = 0

    venues.each_with_index do |venue, index|
      puts "\n[#{index + 1}/#{venues.length}] #{venue.name}"
      puts "  URL: #{venue.website}"

      # Check robots.txt
      robots_status = ResponsibleScraperConfig.check_robots_txt(venue.website)
      if robots_status == :discouraged
        puts "  🤖 Skipped: robots.txt discourages crawling"
        next
      end

      # Respectful delay (with override option)
      if index > 0
        if delay_override
          puts "  ⏱️  Custom delay: #{delay_override}s"
          sleep(delay_override)
        else
          ResponsibleScraperConfig.respectful_delay(venue.name)
        end
      end

      begin
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }

        gigs = scraper.scrape_venue_optimized(venue_config)

        if gigs&.any?
          valid_gigs = scraper.filter_valid_gigs(gigs)
          puts "  🔧 Filtered: #{valid_gigs.length}/#{gigs.length} valid"

          if valid_gigs.any?
            db_result = scraper.send(:save_gigs_to_database, valid_gigs, venue.name)
            puts "  ✅ Success: #{db_result[:saved]} saved, #{db_result[:skipped]} skipped"
            batch_gigs += valid_gigs.length
            batch_successful += 1
          else
            puts "  ⚠️  No valid current gigs"
          end
        else
          puts "  ❌ No gigs found"
        end

      rescue => e
        error_type = ResponsibleScraperConfig.enhanced_error_handling(e, venue.name, venue.website)
        puts "  ❌ Error (#{error_type}): #{e.message}"

        # Stop batch if being blocked
        if error_type == :blocked
          puts "  🛑 Stopping batch due to blocking"
          break
        end
      end
    end

    {
      successful_venues: batch_successful,
      total_gigs: batch_gigs
    }
  end
end
