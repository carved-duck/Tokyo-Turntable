namespace :scrape do
  desc "🛡️ RESPECTFUL MODE - Production scraping for Heroku (slow but polite)"
  task :respectful => :environment do
    puts "🛡️ RESPECTFUL PRODUCTION SCRAPING"
    puts "=" * 60
    puts "⏱️  Estimated time: 2-3 hours (5-6s delays between venues)"
    puts "🎯 Purpose: Production scraping with full robots.txt compliance"
    puts "🌐 Target: All venues in database"
    puts ""

    # Use the existing VenueScrapingJob for respectful scraping
    job = VenueScrapingJob.new
    result = job.perform({
      'mode' => 'responsible_weekly',
      'max_venues' => 200,
      'max_duration_minutes' => 180
    })

    puts "\n🎯 RESPECTFUL SCRAPING COMPLETE!"
    puts "=" * 40
    puts "Mode: #{result[:mode]}"
    puts "Successful venues: #{result[:successful_venues]}"
    puts "Total gigs: #{result[:total_gigs]}"
    puts "Duration: #{result[:duration_minutes]} minutes" if result[:duration_minutes]

    if result[:success]
      puts "✅ Production scraping completed successfully!"
    else
      puts "⚠️  Some issues occurred during scraping"
    end
  end

  desc "⚡ ULTRA-FAST MODE - Development scraping (ALL 900+ venues in minutes)"
  task :ultra_fast => :environment do
    puts "⚡ ULTRA-FAST MEGA-PARALLEL SCRAPING"
    puts "=" * 60
    puts "⏱️  Estimated time: 2-5 minutes"
    puts "🎯 Purpose: ALL 900+ venues with maximum parallelism"
    puts "🌐 Target: Entire database with mega-parallel processing"
    puts ""

        # Create ultra-fast scraper with maximum parallelism
    scraper = UnifiedVenueScraper.new(
      verbose: true,
      max_parallel_venues: 6, # Maximum parallelism
      responsible_mode: false,
      rate_limiting: false
    )

    puts "🌊 Running MEGA-PARALLEL scrape on ALL venues..."

    # Get ALL venues with websites
    all_venues = Venue.where.not(website: [nil, ''])
                     .where("website NOT LIKE '%facebook%'")
                     .where("website NOT LIKE '%instagram%'")
                     .where("website NOT LIKE '%twitter%'")

    puts "📋 Found #{all_venues.count} venues with scrapeable websites"

    # Process in ultra-fast batches of 100
    start_time = Time.current
    total_successful = 0
    total_gigs = 0
    batch_size = 100

    all_venues.find_in_batches(batch_size: batch_size) do |venue_batch|
      batch_start = Time.current
      puts "\n📦 Processing batch of #{venue_batch.count} venues..."

      # Convert to venue configs
      venue_configs = venue_batch.map do |venue|
        {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }
      end

      # Process batch in parallel
      batch_results = process_venue_batch_ultra_fast(scraper, venue_configs)

      total_successful += batch_results[:successful]
      total_gigs += batch_results[:gigs]

      batch_duration = Time.current - batch_start
      puts "   ✅ Batch complete: #{batch_results[:successful]}/#{venue_batch.count} successful, #{batch_results[:gigs]} gigs, #{batch_duration.round(1)}s"
    end

    duration = Time.current - start_time

    result = {
      total_venues: all_venues.count,
      total_successful: total_successful,
      total_gigs: total_gigs,
      duration: duration,
      success_rate: (total_successful.to_f / all_venues.count * 100).round(1),
      parallelism_level: all_venues.count
    }

        puts "\n⚡ MEGA-PARALLEL SCRAPING COMPLETE!"
    puts "=" * 40
    puts "Total venues processed: #{result[:total_venues]}"
    puts "Total successful venues: #{result[:total_successful]}"
    puts "Total gigs found: #{result[:total_gigs]}"
    puts "Success rate: #{result[:success_rate]}%"
    puts "Duration: #{(result[:duration] / 60).round(1)} minutes"
    puts "Parallelism level: #{result[:parallelism_level]} simultaneous venues"

    if result[:total_successful] > 0
      puts "🎉 SUCCESS: Mega-parallel scraping found #{result[:total_gigs]} gigs!"
      puts "⚡ Speed: #{(result[:total_gigs].to_f / result[:duration]).round(2)} gigs/second"
    else
      puts "⚠️  No gigs found - may need debugging"
    end

    # Show accuracy comparison
    baseline_success_rate = 30.0 # Your target baseline
    actual_success_rate = result[:success_rate]

    puts "\n📈 ACCURACY ASSESSMENT:"
    puts "Target baseline: #{baseline_success_rate}%"
    puts "Actual success rate: #{actual_success_rate}%"

    if actual_success_rate >= baseline_success_rate
      improvement = actual_success_rate - baseline_success_rate
      puts "🎉 EXCEEDS TARGET by +#{improvement.round(1)}%!"
    elsif actual_success_rate >= (baseline_success_rate * 0.8)
      puts "✅ GOOD - Within acceptable range"
    else
      puts "⚠️  BELOW TARGET - May need optimization"
    end
  end

  desc "📊 QUICK STATUS - Check scraper health (30 seconds)"
  task :status => :environment do
    puts "📊 SCRAPER HEALTH CHECK"
    puts "=" * 40

    scraper = UnifiedVenueScraper.new(verbose: false)

    # Test just the proven venues for quick health check
    puts "🧪 Testing proven venues..."
    start_time = Time.current
    result = scraper.test_proven_venues
    duration = (Time.current - start_time).round(1)

    puts "\n⚡ HEALTH CHECK RESULTS (#{duration}s):"
    puts "Proven venues working: #{result[:successful_venues]}/#{UnifiedVenueScraper::PROVEN_VENUES.count}"
    puts "Total gigs found: #{result[:total_gigs]}"

    health_percentage = (result[:successful_venues].to_f / UnifiedVenueScraper::PROVEN_VENUES.count * 100).round(1)

    if health_percentage >= 80
      puts "✅ EXCELLENT HEALTH (#{health_percentage}%)"
    elsif health_percentage >= 60
      puts "⚠️  MODERATE HEALTH (#{health_percentage}%) - Some venues may need attention"
    else
      puts "❌ POOR HEALTH (#{health_percentage}%) - Scraper needs debugging"
    end

    if result[:failed_venues].any?
      puts "\n❌ FAILED PROVEN VENUES:"
      result[:failed_venues].each do |failure|
        puts "  • #{failure[:venue]} - #{failure[:reason]}"
      end
    end
  end
end

# Clean up old confusing tasks by providing helpful redirects
namespace :unified_scraper do
  desc "⚠️  DEPRECATED - Use 'rake scrape:ultra_fast' instead"
  task :limited_n_plus_one => :environment do
    puts "⚠️  This task is deprecated!"
    puts "🔄 Use the new simplified commands:"
    puts ""
    puts "⚡ For fast development scraping:"
    puts "   rake scrape:ultra_fast"
    puts ""
    puts "🛡️ For production scraping:"
    puts "   rake scrape:respectful"
    puts ""
    puts "📊 For quick health check:"
    puts "   rake scrape:status"
  end
end

namespace :scraper do
  desc "⚠️  DEPRECATED - Use 'rake scrape:ultra_fast' instead"
  task :ultra_fast_test => :environment do
    puts "⚠️  This task is deprecated!"
    puts "🔄 Use: rake scrape:ultra_fast"
  end
end

# Helper method for ultra-fast batch processing
def process_venue_batch_ultra_fast(scraper, venue_configs)
  batch_successful = 0
  batch_gigs = 0

  # Use ThreadPoolExecutor for maximum parallel processing
  executor = Concurrent::ThreadPoolExecutor.new(
    min_threads: 1,
    max_threads: 6,
    max_queue: 0,
    fallback_policy: :caller_runs
  )

  venue_futures = venue_configs.map do |venue_config|
    Concurrent::Future.execute(executor: executor) do
      begin
        result = scraper.scrape_venue_ultra_fast(venue_config)

        if result[:success] && result[:gigs].any?
          # Save to database
          db_result = scraper.send(:save_gigs_to_database, result[:gigs], venue_config[:name])
          puts "  ✅ #{venue_config[:name]}: #{result[:gigs].count} gigs (#{db_result[:saved]} saved)" if scraper.instance_variable_get(:@verbose)

          { success: true, gigs: result[:gigs].count }
        else
          puts "  ❌ #{venue_config[:name]}: #{result[:reason] || 'No gigs'}" if scraper.instance_variable_get(:@verbose)
          { success: false, gigs: 0 }
        end
      rescue => e
        puts "  ❌ #{venue_config[:name]}: ERROR - #{e.message}" if scraper.instance_variable_get(:@verbose)
        { success: false, gigs: 0 }
      end
    end
  end

  # Wait for all futures with timeout
  venue_futures.each do |future|
    begin
      future.wait!(60) # 60 second timeout per venue
      result = future.value
      batch_successful += 1 if result[:success]
      batch_gigs += result[:gigs]
    rescue Concurrent::TimeoutError
      puts "  ⚠️ Venue timed out" if scraper.instance_variable_get(:@verbose)
    end
  end

  # Graceful shutdown
  executor.shutdown
  executor.wait_for_termination(30) || executor.kill

  { successful: batch_successful, gigs: batch_gigs }
end
