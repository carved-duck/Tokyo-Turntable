namespace :scrape do
  desc "Polite venue scraping for Heroku background jobs (respectful rate limiting)"
  task :polite => :environment do
    puts "🤝 POLITE VENUE SCRAPING FOR HEROKU"
    puts "=" * 50
    puts "🎯 Processing all venues with respectful rate limiting"
    puts "📊 Optimized for background jobs and production stability"
    puts

    scraper = UnifiedVenueScraper.new(
      verbose: true,
      max_parallel_venues: 5, # Low parallelism for Heroku
      responsible_mode: true,  # Respectful delays
      rate_limiting: true      # Enable rate limiting
    )

    start_time = Time.current

    # Get all venues with websites (excluding social media)
    venues = Venue.where.not(website: [nil, ''])
                  .where.not("website ILIKE '%facebook%'")
                  .where.not("website ILIKE '%instagram%'")
                  .where.not("website ILIKE '%twitter%'")
                  .where.not("website ILIKE '%tiktok%'")

    puts "📊 Processing #{venues.count} venues with polite approach..."

    # Convert to venue configs
    venue_configs = venues.map do |venue|
      {
        name: venue.name,
        url: venue.website,
        selectors: scraper.send(:get_general_selectors)
      }
    end

    # Process venues in small batches with delays
    successful_venues = 0
    total_gigs = 0
    batch_size = 10

    venue_configs.each_slice(batch_size).with_index do |batch, batch_index|
      batch_start = Time.current
      puts "\n📦 Processing batch #{batch_index + 1}/#{(venue_configs.count.to_f/batch_size).ceil} (#{batch.count} venues)..."

      batch_successful = 0
      batch_gigs = 0

      batch.each do |venue_config|
        result = scraper.scrape_venue_ultra_fast(venue_config)

        if result[:success]
          batch_successful += 1
          batch_gigs += result[:gigs].length

          # Save to database
          db_result = scraper.send(:save_gigs_to_database, result[:gigs], venue_config[:name])
          puts "  ✅ #{venue_config[:name]}: #{result[:gigs].length} gigs (#{db_result[:saved]} saved)" if scraper.instance_variable_get(:@verbose)
        else
          puts "  ❌ #{venue_config[:name]}: #{result[:reason]}" if scraper.instance_variable_get(:@verbose)
        end

        # Polite delay between venues
        sleep(1)
      end

      successful_venues += batch_successful
      total_gigs += batch_gigs

      batch_duration = Time.current - batch_start
      batch_success_rate = (batch_successful.to_f / batch.count * 100).round(1)

      puts "  📊 Batch results: #{batch_successful}/#{batch.count} successful (#{batch_success_rate}%), #{batch_gigs} gigs, #{batch_duration.round(1)}s"

      # Polite delay between batches
      sleep(3) unless batch_index == (venue_configs.count.to_f/batch_size).ceil - 1
    end

    duration = Time.current - start_time
    success_rate = (successful_venues.to_f / venue_configs.count * 100).round(1)

    puts "\n🤝 POLITE SCRAPING COMPLETE!"
    puts "=" * 50
    puts "📊 Total venues processed: #{venue_configs.count}"
    puts "✅ Successful venues: #{successful_venues}"
    puts "🎵 Total gigs found: #{total_gigs}"
    puts "📈 Success rate: #{success_rate}%"
    puts "⏱️  Duration: #{(duration / 60).round(1)} minutes"
    puts "⚡ Speed: #{(total_gigs.to_f / duration).round(2)} gigs/second"
    puts "🎯 Strategy: Respectful scraping for production/Heroku"
  end

  desc "Ultra-fast venue scraping for testing and development (maximum speed)"
  task :ultra_fast => :environment do
    puts "🚀 ULTRA-FAST VENUE SCRAPING"
    puts "=" * 50
    puts "🎯 Processing all venues with maximum speed and optimizations"
    puts "📊 All venues, intelligent blacklisting, high parallelism"
    puts

    scraper = UnifiedVenueScraper.new(
      verbose: true,
      max_parallel_venues: 25, # High but manageable parallelism
      responsible_mode: false,  # No delays
      rate_limiting: false      # Maximum speed
    )

    start_time = Time.current

    # Get all venues with websites (excluding social media)
    venues = Venue.where.not(website: [nil, ''])
                  .where.not("website ILIKE '%facebook%'")
                  .where.not("website ILIKE '%instagram%'")
                  .where.not("website ILIKE '%twitter%'")
                  .where.not("website ILIKE '%tiktok%'")

    puts "📊 Processing #{venues.count} venues with ultra-fast approach..."

    # Convert to venue configs
    venue_configs = venues.map do |venue|
      {
        name: venue.name,
        url: venue.website,
        selectors: scraper.send(:get_general_selectors)
      }
    end

    # Process venues in optimized batches
    successful_venues = 0
    total_gigs = 0
    batch_size = 25

    venue_configs.each_slice(batch_size).with_index do |batch, batch_index|
      batch_start = Time.current
      puts "\n📦 Processing batch #{batch_index + 1}/#{(venue_configs.count.to_f/batch_size).ceil} (#{batch.count} venues)..."

      batch_successful = 0
      batch_gigs = 0

      batch.each do |venue_config|
        result = scraper.scrape_venue_ultra_fast(venue_config)

        if result[:success]
          batch_successful += 1
          batch_gigs += result[:gigs].length

          # Save to database
          db_result = scraper.send(:save_gigs_to_database, result[:gigs], venue_config[:name])
          puts "  ✅ #{venue_config[:name]}: #{result[:gigs].length} gigs (#{db_result[:saved]} saved)" if scraper.instance_variable_get(:@verbose)
        else
          puts "  ❌ #{venue_config[:name]}: #{result[:reason]}" if scraper.instance_variable_get(:@verbose)
        end
      end

      successful_venues += batch_successful
      total_gigs += batch_gigs

      batch_duration = Time.current - batch_start
      batch_success_rate = (batch_successful.to_f / batch.count * 100).round(1)

      puts "  📊 Batch results: #{batch_successful}/#{batch.count} successful (#{batch_success_rate}%), #{batch_gigs} gigs, #{batch_duration.round(1)}s"

      # Brief pause between batches (minimal)
      sleep(1) unless batch_index == (venue_configs.count.to_f/batch_size).ceil - 1
    end

    duration = Time.current - start_time
    success_rate = (successful_venues.to_f / venue_configs.count * 100).round(1)

    puts "\n🚀 ULTRA-FAST SCRAPING COMPLETE!"
    puts "=" * 50
    puts "📊 Total venues processed: #{venue_configs.count}"
    puts "✅ Successful venues: #{successful_venues}"
    puts "🎵 Total gigs found: #{total_gigs}"
    puts "📈 Success rate: #{success_rate}%"
    puts "⏱️  Duration: #{(duration / 60).round(1)} minutes"
    puts "⚡ Speed: #{(total_gigs.to_f / duration).round(2)} gigs/second"
    puts "🎯 Strategy: Maximum speed for testing and development"
  end

  desc "Show scraper options and recommendations"
  task :help => :environment do
    puts "🎯 TOKYO TURNTABLE SCRAPERS"
    puts "=" * 50
    puts
    puts "Available scrapers:"
    puts
    puts "1. 🤝 rails scrape:polite"
    puts "   • Processes: All #{Venue.where.not(website: [nil, '']).count} venues"
    puts "   • Parallelism: Low (5 simultaneous)"
    puts "   • Rate limiting: Enabled with delays"
    puts "   • Best for: Heroku background jobs, production"
    puts "   • Duration: ~45-60 minutes (respectful)"
    puts "   • Strategy: Stable, respectful, production-safe"
    puts
    puts "2. 🚀 rails scrape:ultra_fast"
    puts "   • Processes: All #{Venue.where.not(website: [nil, '']).count} venues"
    puts "   • Parallelism: High (25 simultaneous)"
    puts "   • Rate limiting: Disabled for maximum speed"
    puts "   • Best for: Testing, development, manual runs"
    puts "   • Duration: ~8-12 minutes (maximum speed)"
    puts "   • Strategy: All optimizations, intelligent blacklisting"
    puts
    puts "💡 Recommendations:"
    puts "   • Use 'polite' for Heroku scheduled jobs"
    puts "   • Use 'ultra_fast' for testing and development"
    puts "   • Both process ALL venues (no selection needed)"
    puts "   • Both preserve past gigs (no deletion)"
    puts
    puts "📊 Current database status:"
    puts "   • Total gigs: #{Gig.count}"
    puts "   • Total venues: #{Venue.count}"
    puts "   • Total bands: #{Band.count}"
  end
end
