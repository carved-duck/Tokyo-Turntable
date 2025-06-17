namespace :scrape do
  desc "DEVELOPMENT ONLY: Fast aggressive scraping for testing (NOT for production)"
  task :dev_fast, [:limit] => :environment do |t, args|
    limit = args[:limit]&.to_i

    puts "🚨 DEVELOPMENT FAST SCRAPER - NOT FOR PRODUCTION!"
    puts "=" * 60
    puts "⚠️  WARNING: This uses aggressive scraping settings"
    puts "⚠️  ONLY use this in development for testing purposes"
    puts "⚠️  Switch to responsible scraping in production"
    puts "=" * 60

    # Check environment safety
    unless Rails.env.development?
      puts "🛑 ERROR: This task can only run in development environment"
      puts "Current environment: #{Rails.env}"
      puts "Use 'bundle exec rake scrape:full_responsible' for production"
      exit 1
    end

    puts "\n🏎️ FAST DEVELOPMENT SCRAPING"
    puts "-" * 30
    puts "Environment: #{Rails.env} ✅"
    puts "Limit: #{limit || 'all venues (~856)'}"
    puts "Expected time: ~1 hour"
    puts "Rate limiting: MINIMAL (aggressive)"
    puts ""

    print "🤔 Continue with fast development scraping? (y/N): "
    response = STDIN.gets.chomp.downcase

    unless response == 'y' || response == 'yes'
      puts "❌ Fast scraping cancelled."
      exit
    end

    # Use the original ultra-fast scraper settings
    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 2,  # Original parallelism
      verbose: true,
      responsible_mode: false,  # Disable responsible mode
      rate_limiting: false,     # Disable extra rate limiting
      respect_robots: false     # Skip robots.txt checking for speed
    )

    puts "\n🚀 Starting ultra-fast development scraping..."
    start_time = Time.current

    if limit
      # Limited test - use the existing optimized method
      puts "📊 Running limited test with #{limit} venues..."
      result = scraper.ultra_fast_n_plus_one_test(limit)

      puts "\n🎯 LIMITED FAST SCRAPE COMPLETE"
      puts "-" * 30
      puts "Total successful venues: #{result[:total_successful_venues]}"
      puts "Total gigs found: #{result[:total_gigs]}"
      puts "New venues discovered: #{result[:new_venues_added]}"
      puts "Duration: #{((Time.current - start_time) / 1.minute).round(1)} minutes"

    else
      # Full scrape - use all venues with original fast settings
      puts "📊 Running FULL fast scrape of all venues..."
      result = run_full_fast_scrape(scraper)

      puts "\n🎉 FULL FAST SCRAPE COMPLETE"
      puts "-" * 30
      puts "Total venues processed: #{result[:total_processed]}"
      puts "Total successful venues: #{result[:total_successful]}"
      puts "Total gigs found: #{result[:total_gigs]}"
      puts "Success rate: #{result[:success_rate]}%"
      puts "Duration: #{((Time.current - start_time) / 1.minute).round(1)} minutes"
    end

    puts "\n⚠️  REMINDER: Use responsible scraping in production!"
    puts "   Production command: bundle exec rake scrape:full_responsible"
  end

  desc "Quick proven venues test with original fast settings"
  task :dev_proven => :environment do
    unless Rails.env.development?
      puts "🛑 ERROR: Development-only task"
      exit 1
    end

    puts "⚡ FAST PROVEN VENUES TEST (Development)"
    puts "=" * 50

    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 2,
      verbose: true,
      responsible_mode: false
    )

    # Use the original parallel method for speed
    result = scraper.test_proven_venues_parallel(verbose: true)

    puts "\n🎯 FAST PROVEN VENUES COMPLETE"
    puts "-" * 30
    puts "Successful venues: #{result[:successful_venues]}"
    puts "Total gigs: #{result[:total_gigs]}"
    puts "Speed: MAXIMUM (development mode)"
  end

  desc "Compare development fast vs responsible scraping on same sample"
  task :compare_speeds => :environment do
    unless Rails.env.development?
      puts "🛑 ERROR: Development-only task"
      exit 1
    end

    puts "⚡ vs 🛡️ SPEED COMPARISON TEST"
    puts "=" * 50
    puts "Testing 10 venues with both approaches"
    puts ""

    # Get test sample
    test_venues = Venue.where.not(website: [nil, ''])
                       .where("website NOT LIKE '%facebook%'")
                       .limit(10)

    # Test 1: Fast scraper
    puts "🏎️ ROUND 1: Fast Development Scraper"
    puts "-" * 40
    fast_start = Time.current

    fast_scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 2,
      verbose: false,
      responsible_mode: false
    )

    fast_results = test_venues_sample(fast_scraper, test_venues, delay: 0.5)
    fast_duration = Time.current - fast_start

    puts "\n🛡️ ROUND 2: Responsible Scraper"
    puts "-" * 40
    responsible_start = Time.current

    responsible_scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 1,
      verbose: false,
      responsible_mode: true,
      rate_limiting: true
    )

    responsible_results = test_venues_sample(responsible_scraper, test_venues, delay: 3.0)
    responsible_duration = Time.current - responsible_start

    # Comparison
    puts "\n📊 SPEED COMPARISON RESULTS"
    puts "=" * 40
    puts "Fast Scraper:"
    puts "  Duration: #{fast_duration.round(1)} seconds"
    puts "  Success rate: #{fast_results[:success_rate]}%"
    puts "  Total gigs: #{fast_results[:total_gigs]}"
    puts ""
    puts "Responsible Scraper:"
    puts "  Duration: #{responsible_duration.round(1)} seconds"
    puts "  Success rate: #{responsible_results[:success_rate]}%"
    puts "  Total gigs: #{responsible_results[:total_gigs]}"
    puts ""
    puts "📈 Analysis:"
    puts "  Speed difference: #{(responsible_duration / fast_duration).round(1)}x slower"
    puts "  Accuracy difference: #{(responsible_results[:success_rate] - fast_results[:success_rate]).round(1)}%"
    puts ""
    puts "💡 Recommendation:"
    if fast_results[:success_rate] > responsible_results[:success_rate]
      puts "  Fast scraper: Better for development testing"
      puts "  Responsible scraper: Better for production safety"
    else
      puts "  Responsible scraper: Better accuracy AND safety"
    end
  end

  private

  def run_full_fast_scrape(scraper)
    total_processed = 0
    total_successful = 0
    total_gigs = 0

    # Get all scrapeable venues
    venues = Venue.where.not(website: [nil, ''])
                 .where("website NOT LIKE '%facebook%'")
                 .where("website NOT LIKE '%instagram%'")
                 .where("website NOT LIKE '%twitter%'")

    puts "📊 Processing #{venues.count} venues with fast settings..."

    venues.find_in_batches(batch_size: 50) do |venue_batch|
      batch_start = Time.current
      batch_successful = 0
      batch_gigs = 0

      venue_batch.each do |venue|
        begin
          venue_config = {
            name: venue.name,
            url: venue.website,
            selectors: scraper.send(:get_general_selectors)
          }

          # Fast scraping with minimal delays
          gigs = scraper.scrape_venue_optimized(venue_config)

          if gigs&.any?
            valid_gigs = scraper.filter_valid_gigs(gigs)
            if valid_gigs.any?
              db_result = scraper.send(:save_gigs_to_database, valid_gigs, venue.name)
              batch_successful += 1
              batch_gigs += valid_gigs.length
            end
          end

          total_processed += 1

          # Minimal delay (much faster than responsible)
          sleep(0.5) unless venue == venue_batch.last

        rescue => e
          puts "    ❌ #{venue.name}: #{e.message}" if scraper.instance_variable_get(:@verbose)
        end
      end

      total_successful += batch_successful
      total_gigs += batch_gigs

      batch_duration = Time.current - batch_start
      puts "  Batch: #{batch_successful}/#{venue_batch.size} successful, #{batch_gigs} gigs, #{batch_duration.round(1)}s"
    end

    {
      total_processed: total_processed,
      total_successful: total_successful,
      total_gigs: total_gigs,
      success_rate: (total_successful.to_f / total_processed * 100).round(1)
    }
  end

  def test_venues_sample(scraper, venues, delay:)
    successful = 0
    total_gigs = 0

    venues.each_with_index do |venue, index|
      begin
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }

        gigs = scraper.scrape_venue_optimized(venue_config)

        if gigs&.any?
          valid_gigs = scraper.filter_valid_gigs(gigs)
          if valid_gigs.any?
            successful += 1
            total_gigs += valid_gigs.length
          end
        end

        sleep(delay) unless index == venues.length - 1

      rescue => e
        # Silent error handling for comparison
      end
    end

    {
      success_rate: (successful.to_f / venues.length * 100).round(1),
      total_gigs: total_gigs
    }
  end
end
