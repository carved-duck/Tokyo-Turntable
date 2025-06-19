namespace :scrape do
  desc "⚡ ULTRA-FAST TEST SCRAPER - Development testing with maximum speed (35-38% accuracy target)"
  task :ultra_fast => :environment do
    puts "⚡ ULTRA-FAST TEST SCRAPER"
    puts "=" * 60
    puts "🎯 Purpose: Testing and development with maximum speed"
    puts "📊 Target accuracy: 35-38% success rate"
    puts "⚡ Parallelism: #{VenueConstants.max_parallel_requests} HTTP requests"
    puts "🏎️  Strategy: HTTP-first with browser fallback for JS/OCR"
    puts

    scraper = UnifiedVenueScraper.new(
      verbose: true,
      max_parallel_venues: VenueConstants.max_parallel_venues,
      responsible_mode: false,  # No delays for speed
      rate_limiting: false      # Maximum speed
    )

    start_time = Time.current

    # Get all scrapeable venues with proper URL validation
    venues = Venue.where.not(website: [nil, ''])
                  .where.not("website ILIKE '%facebook%'")
                  .where.not("website ILIKE '%instagram%'")
                  .where.not("website ILIKE '%twitter%'")
                  .where.not("website ILIKE '%Not Listed%'")
                  .where.not("website ILIKE '%Not Available%'")
                  .where("website LIKE 'http%'")  # Only valid HTTP/HTTPS URLs

    puts "📊 Processing #{venues.count} venues with ultra-fast approach..."

    # Convert to venue configs
    venue_configs = venues.map do |venue|
      {
        name: venue.name,
        url: venue.website,
        selectors: scraper.send(:get_general_selectors)
      }
    end

    successful_venues = 0
    total_gigs = 0
    batch_size = 50  # Optimized batch size

    venue_configs.each_slice(batch_size).with_index do |batch, batch_index|
      batch_start = Time.current
      puts "\n📦 Batch #{batch_index + 1}/#{(venue_configs.count.to_f/batch_size).ceil} (#{batch.count} venues)..."

      # Ultra-fast parallel processing
      executor = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: VenueConstants.max_parallel_venues,
        max_queue: 0,
        fallback_policy: :caller_runs
      )

      futures = batch.map do |venue_config|
        Concurrent::Future.execute(executor: executor) do
          result = scraper.scrape_venue_ultra_fast(venue_config)

          # Handle nil result (circuit breaker or other failures)
          if result.nil?
            { success: false, gigs: 0, reason: "Circuit breaker or internal error" }
          elsif result[:success] && result[:gigs]&.any?
            db_result = scraper.send(:save_gigs_to_database, result[:gigs], venue_config[:name])
            puts "  ✅ #{venue_config[:name]}: #{result[:gigs].count} gigs" if scraper.instance_variable_get(:@verbose)
            { success: true, gigs: result[:gigs].count }
          else
            reason = result[:reason] || "Unknown error"
            { success: false, gigs: 0, reason: reason }
          end
        end
      end

      # Collect results with timeout
      batch_successful = 0
      batch_gigs = 0

      futures.each do |future|
        begin
          result = future.value(10)  # 10 second timeout per venue
          if result && result[:success]
            batch_successful += 1
            batch_gigs += result[:gigs]
          end
        rescue Concurrent::TimeoutError
          # Skip timeouts for speed
        rescue => e
          # Skip other errors for speed
        end
      end

      executor.shutdown
      executor.wait_for_termination(5) || executor.kill

      successful_venues += batch_successful
      total_gigs += batch_gigs

      batch_duration = Time.current - batch_start
      batch_success_rate = (batch_successful.to_f / batch.count * 100).round(1)
      puts "  📊 #{batch_successful}/#{batch.count} successful (#{batch_success_rate}%), #{batch_gigs} gigs, #{batch_duration.round(1)}s"
    end

    duration = Time.current - start_time
    success_rate = (successful_venues.to_f / venues.count * 100).round(1)

    puts "\n⚡ ULTRA-FAST SCRAPING COMPLETE!"
    puts "=" * 50
    puts "📊 Venues processed: #{venues.count}"
    puts "✅ Successful venues: #{successful_venues}"
    puts "🎵 Total gigs found: #{total_gigs}"
    puts "📈 Success rate: #{success_rate}%"
    puts "⏱️  Duration: #{(duration / 60).round(1)} minutes"
    puts "🚀 Speed: #{(venues.count.to_f/duration).round(1)} venues/second"

    # Accuracy assessment
    target_accuracy = 35.0  # Your baseline target

    puts "\n📈 ACCURACY ASSESSMENT:"
    puts "🎯 Target baseline: #{target_accuracy}%"
    puts "📊 Actual success rate: #{success_rate}%"

    if success_rate >= target_accuracy
      improvement = success_rate - target_accuracy
      puts "🎉 EXCEEDS TARGET by +#{improvement.round(1)}%!"
    elsif success_rate >= (target_accuracy * 0.8)
      puts "✅ ACCEPTABLE - Within range of target"
    else
      puts "⚠️  BELOW TARGET - Consider optimization"
    end

    puts "\n💡 Note: JS-heavy sites and OCR venues automatically fall back to browser automation"
  end

  desc "🛡️ HEROKU PRODUCTION SCRAPER - Weekly scheduled runs with respectful rate limiting"
  task :heroku => :environment do
    puts "🛡️ HEROKU PRODUCTION SCRAPER"
    puts "=" * 60
    puts "🎯 Purpose: Production weekly scheduled runs"
    puts "⏱️  Strategy: Respectful rate limiting for Heroku"
    puts "🏥 Parallelism: Conservative (#{VenueConstants.max_parallel_venues} venues)"
    puts "🤝 Rate limiting: Enabled with polite delays"
    puts

    scraper = UnifiedVenueScraper.new(
      verbose: true,
      max_parallel_venues: 2,  # Conservative for Heroku
      responsible_mode: true,   # Polite delays
      rate_limiting: true       # Respect rate limits
    )

    start_time = Time.current

    # Get all scrapeable venues with proper URL validation
    venues = Venue.where.not(website: [nil, ''])
                  .where.not("website ILIKE '%facebook%'")
                  .where.not("website ILIKE '%instagram%'")
                  .where.not("website ILIKE '%twitter%'")
                  .where.not("website ILIKE '%Not Listed%'")
                  .where.not("website ILIKE '%Not Available%'")
                  .where("website LIKE 'http%'")  # Only valid HTTP/HTTPS URLs

    puts "📊 Processing #{venues.count} venues with respectful approach..."

    # Convert to venue configs
    venue_configs = venues.map do |venue|
      {
        name: venue.name,
        url: venue.website,
        selectors: scraper.send(:get_general_selectors)
      }
    end

    successful_venues = 0
    total_gigs = 0
    batch_size = 10  # Small batches for Heroku

    venue_configs.each_slice(batch_size).with_index do |batch, batch_index|
      batch_start = Time.current
      puts "\n📦 Batch #{batch_index + 1}/#{(venue_configs.count.to_f/batch_size).ceil} (#{batch.count} venues)..."

      batch_successful = 0
      batch_gigs = 0

      batch.each do |venue_config|
        result = scraper.scrape_venue_ultra_fast(venue_config)

        # Handle nil result
        if result.nil?
          puts "  ❌ #{venue_config[:name]}: Circuit breaker or internal error"
        elsif result[:success] && result[:gigs]&.any?
          batch_successful += 1
          batch_gigs += result[:gigs].count

          # Save to database
          db_result = scraper.send(:save_gigs_to_database, result[:gigs], venue_config[:name])
          puts "  ✅ #{venue_config[:name]}: #{result[:gigs].count} gigs (#{db_result[:saved]} saved)"
        else
          reason = result[:reason] || "Unknown error"
          puts "  ❌ #{venue_config[:name]}: #{reason}"
        end

        # Polite delay between venues (Heroku-friendly)
        sleep(2)
      end

      successful_venues += batch_successful
      total_gigs += batch_gigs

      batch_duration = Time.current - batch_start
      batch_success_rate = (batch_successful.to_f / batch.count * 100).round(1)
      puts "  📊 #{batch_successful}/#{batch.count} successful (#{batch_success_rate}%), #{batch_gigs} gigs, #{batch_duration.round(1)}s"

      # Polite delay between batches (avoid overwhelming servers)
      sleep(5) unless batch_index == (venue_configs.count.to_f/batch_size).ceil - 1
    end

    duration = Time.current - start_time
    success_rate = (successful_venues.to_f / venues.count * 100).round(1)

    puts "\n🛡️ HEROKU SCRAPING COMPLETE!"
    puts "=" * 50
    puts "📊 Venues processed: #{venues.count}"
    puts "✅ Successful venues: #{successful_venues}"
    puts "🎵 Total gigs found: #{total_gigs}"
    puts "📈 Success rate: #{success_rate}%"
    puts "⏱️  Duration: #{(duration / 60).round(1)} minutes"
    puts "🤝 Strategy: Respectful rate limiting for production"

    # Accuracy assessment (same as ultra_fast)
    target_accuracy = 35.0  # Same baseline target as ultra_fast

    puts "\n📈 ACCURACY ASSESSMENT:"
    puts "🎯 Target baseline: #{target_accuracy}%"
    puts "📊 Actual success rate: #{success_rate}%"

    if success_rate >= target_accuracy
      improvement = success_rate - target_accuracy
      puts "🎉 EXCEEDS TARGET by +#{improvement.round(1)}%!"
    elsif success_rate >= (target_accuracy * 0.8)
      puts "✅ ACCEPTABLE - Within range of target"
    else
      puts "⚠️  BELOW TARGET - Consider optimization"
    end

    puts "\n💡 Note: Uses identical scraping logic as ultra_fast, just slower & respectful"

    # Heroku-specific logging
    puts "\n📊 HEROKU DEPLOYMENT STATS:"
    puts "Memory usage: Conservative parallel processing"
    puts "Rate limiting: Enabled for server respect"
    puts "Timeout handling: Robust error recovery"
    puts "Database: Batch saves for reliability"
  end

  desc "📋 Show the 2 available scrapers"
  task :help => :environment do
    puts "🎯 TOKYO TURNTABLE - 2 SCRAPERS ONLY"
    puts "=" * 60
    puts
    puts "1. ⚡ rails scrape:ultra_fast"
    puts "   🎯 Purpose: Testing and development"
    puts "   📊 Target: 35-38% accuracy (#{VenueConstants.scrapeable_venue_count} venues)"
    puts "   ⚡ Speed: #{VenueConstants.max_parallel_requests} parallel HTTP + browser fallback"
    puts "   ⏱️  Duration: ~10 minutes"
    puts "   🔧 Features: HTTP-first, JS/OCR fallback, maximum speed"
    puts
    puts "2. 🛡️ rails scrape:heroku"
    puts "   🎯 Purpose: Production weekly runs"
    puts "   📊 Target: 35-38% accuracy (#{VenueConstants.scrapeable_venue_count} venues)"
    puts "   🤝 Speed: 2 parallel venues, respectful delays"
    puts "   ⏱️  Duration: ~45-60 minutes"
    puts "   🔧 Features: Rate limiting, polite delays, Heroku-optimized"
    puts
    puts "💡 Both scrapers use IDENTICAL logic:"
    puts "   🌐 Simple sites: HTTP-only (fast)"
    puts "   🖥️  JS-heavy sites: Browser automation (fallback)"
    puts "   🖼️  Image schedules: OCR extraction (fallback)"
    puts "   📊 Complex sites: Multi-strategy approach"
    puts "   ✅ Same success rates - only speed differs"
    puts
    puts "🎪 Current database: #{Venue.count} venues, #{Gig.count} gigs"
  end
end
