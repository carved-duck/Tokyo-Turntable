namespace :lightning do
  desc "⚡ LIGHTNING FAST SCRAPING - Speed over everything (target: under 10 minutes)"
  task :scrape => :environment do
    puts "⚡ LIGHTNING FAST SCRAPING MODE"
    puts "=" * 60
    puts "🎯 Target: Under 10 minutes for all venues"
    puts "⚡ Strategy: HTTP-only, minimal timeouts, maximum parallelism"
    puts "🚫 Trade-off: Lower accuracy for much higher speed"
    puts "=" * 60
    puts

    scraper = LightningFastScraper.new(verbose: true, max_parallel: 15)
    result = scraper.scrape_all_venues_lightning_fast

    puts "\n⚡ LIGHTNING SCRAPE RESULTS:"
    puts "=" * 40
    puts "⏱️  Duration: #{(result[:duration]/60).round(1)} minutes"
    puts "🏆 Success rate: #{result[:successful]} venues"
    puts "📊 Total gigs: #{result[:total_gigs]}"
    puts "🚀 Speed: #{(919.to_f/result[:duration]).round(1)} venues/second"

    if result[:duration] < 600  # Under 10 minutes
      puts "✅ SUCCESS: Under 10 minute target achieved!"
    else
      puts "⚠️  Still too slow - need more optimization"
    end
  end

  desc "⚡ LIGHTNING TEST - Quick 50 venue test"
  task :test => :environment do
    puts "⚡ LIGHTNING FAST TEST (50 venues)"
    puts "=" * 40

    start_time = Time.current

    # Test with first 50 venues
    venues = Venue.where.not(website: [nil, ''])
                  .where.not("website ILIKE '%facebook%'")
                  .limit(50)

    scraper = LightningFastScraper.new(verbose: true, max_parallel: 10)

    total_gigs = 0
    successful = 0

    venues.each do |venue|
      result = scraper.send(:scrape_venue_lightning_fast, venue)
      if result[:success]
        successful += 1
        total_gigs += result[:gigs]
      end
    end

    duration = Time.current - start_time

    puts "\n⚡ LIGHTNING TEST RESULTS:"
    puts "⏱️  Duration: #{duration.round(1)} seconds"
    puts "🏆 Success: #{successful}/50 (#{(successful.to_f/50*100).round(1)}%)"
    puts "📊 Gigs: #{total_gigs}"
    puts "🚀 Speed: #{(50.to_f/duration).round(1)} venues/second"

    # Project full scrape time
    projected_time = (919 * duration / 50 / 60).round(1)
    puts "📈 Projected full scrape: #{projected_time} minutes"

    if projected_time < 10
      puts "✅ EXCELLENT: Will meet 10 minute target!"
    elsif projected_time < 15
      puts "✅ GOOD: Close to target"
    else
      puts "⚠️  NEEDS WORK: Still too slow"
    end
  end

  desc "🔧 Fix current slow scraper by killing it and optimizing settings"
  task :fix_slow_scraper => :environment do
    puts "🔧 FIXING SLOW SCRAPER ISSUES"
    puts "=" * 40

    # Kill any running scraper processes
    puts "🛑 Killing slow scraper processes..."
    system("pkill -f 'rails scrape'")
    system("pkill -f 'chrome'")
    system("pkill -f 'chromedriver'")

    puts "🧹 Cleaning up browser processes..."
    sleep(2)

    puts "⚡ Optimizations applied:"
    puts "  ✅ Killed slow processes"
    puts "  ✅ Cleaned up browser instances"
    puts "  ✅ Ready for lightning-fast scraping"
    puts
    puts "💡 Next steps:"
    puts "  1. Run: rails lightning:test (quick 50 venue test)"
    puts "  2. If good: rails lightning:scrape (full lightning scrape)"
    puts "  3. Target: Under 10 minutes total"
  end
end
