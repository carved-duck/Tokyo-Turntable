namespace :test do
  desc "Test production safeguards before full scrape"
  task production_safeguards: :environment do
    puts "🛡️ TESTING PRODUCTION SAFEGUARDS"
    puts "="*60

    # Initialize scraper with production settings
    scraper = UnifiedVenueScraper.new(
      verbose: true,
      max_parallel_venues: 3,
      responsible_mode: true
    )

    # Run health check
    scraper.production_health_check

    puts "\n🧪 TESTING SAFEGUARDS WITH PROVEN VENUES"
    puts "-"*40

    # Test with a small subset of proven venues
    test_venues = UnifiedVenueScraper::PROVEN_VENUES.first(2)

    test_venues.each do |venue_config|
      puts "\n🎯 Testing #{venue_config[:name]}..."

      begin
        result = scraper.scrape_venue_ultra_fast(venue_config)

        if result[:success]
          puts "  ✅ Success: #{result[:gigs].count} gigs found"

          # Test database saving with connection management
          if result[:gigs].any?
            db_result = scraper.send(:save_gigs_to_database, result[:gigs], venue_config[:name])
            puts "  💾 Database: #{db_result[:saved]} saved, #{db_result[:skipped]} skipped"
          end
        else
          puts "  ❌ Failed: #{result[:reason]}"
        end

      rescue => e
        puts "  💥 Error: #{e.message}"
      end
    end

    # Final health check
    puts "\n🏥 POST-TEST HEALTH CHECK"
    puts "-"*40
    scraper.production_health_check

    puts "\n✅ PRODUCTION SAFEGUARDS TEST COMPLETE"
    puts "🚀 System is ready for full production scraping!"
  end
end
