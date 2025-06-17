namespace :venues do
  desc "Test all enhanced scraping improvements and optimizations"
  task test_enhanced: :environment do
    puts '🚀 COMPREHENSIVE ENHANCED SCRAPING TEST'
    puts '======================================'
    puts 'Testing all high-impact fixes, performance optimizations, and scaling improvements'
    puts

    scraper = UnifiedVenueScraper.new(verbose: true)
    start_time = Time.current

    # Test 1: Original 4 proven venues with enhancements
    puts '📊 TEST 1: Enhanced Proven Venues (4 venues)'
    puts '-' * 50

    original_result = scraper.test_proven_venues

    puts "\n✅ Original Proven Venues Results:"
    puts "   Success Rate: #{original_result[:successful_venues]}/4 (#{(original_result[:successful_venues] * 100.0 / 4).round(1)}%)"
    puts "   Total Events: #{original_result[:total_gigs]}"
    puts "   Failed: #{original_result[:failed_venues].map { |f| f[:venue] }.join(', ')}" if original_result[:failed_venues].any?

    # Test 2: New venues (scaling test)
    puts "\n📊 TEST 2: New Venue Scaling (10 additional venues)"
    puts '-' * 50

    new_venues = UnifiedVenueScraper::PROVEN_VENUES[4..-1] # Get the new venues we added
    new_venue_results = { successful_venues: 0, total_gigs: 0, failed_venues: [] }

    if new_venues&.any?
      new_venues.each_with_index do |venue_config, index|
        puts "\n[#{index + 1}/#{new_venues.count}] Testing: #{venue_config[:name]}"
        puts "Strategy: #{venue_config[:strategy]}"

        begin
          gigs = scraper.send(:scrape_venue_optimized, venue_config)
          valid_gigs = scraper.send(:filter_valid_gigs, gigs)

          if valid_gigs.any?
            puts "✅ SUCCESS: #{valid_gigs.count} events"
            scraper.send(:save_gigs_to_database, valid_gigs, venue_config[:name])
            new_venue_results[:successful_venues] += 1
            new_venue_results[:total_gigs] += valid_gigs.count
          else
            puts "❌ NO EVENTS"
            new_venue_results[:failed_venues] << { venue: venue_config[:name], reason: "No events found" }
          end
        rescue => e
          puts "❌ ERROR: #{e.message}"
          new_venue_results[:failed_venues] << { venue: venue_config[:name], reason: e.message }
        end
      end

      puts "\n✅ New Venues Results:"
      puts "   Success Rate: #{new_venue_results[:successful_venues]}/#{new_venues.count} (#{(new_venue_results[:successful_venues] * 100.0 / new_venues.count).round(1)}%)"
      puts "   Total Events: #{new_venue_results[:total_gigs]}"
      puts "   Failed: #{new_venue_results[:failed_venues].map { |f| f[:venue] }.join(', ')}" if new_venue_results[:failed_venues].any?
    else
      puts "   No new venues to test"
    end

    # Test 3: Performance analysis
    puts "\n📊 TEST 3: Performance Analysis"
    puts '-' * 50

    total_time = Time.current - start_time
    total_venues = 4 + (new_venues&.count || 0)
    total_successful = original_result[:successful_venues] + new_venue_results[:successful_venues]
    total_events = original_result[:total_gigs] + new_venue_results[:total_gigs]

    puts "⏱️  Total Time: #{total_time.round(2)} seconds"
    puts "🏆 Overall Success Rate: #{total_successful}/#{total_venues} (#{(total_successful * 100.0 / total_venues).round(1)}%)"
    puts "📊 Total Events Found: #{total_events}"
    puts "⚡ Average Time per Venue: #{(total_time / total_venues).round(2)} seconds"
    puts "🎯 Events per Second: #{(total_events / total_time).round(2)}"

    # Test 4: Strategy effectiveness analysis
    puts "\n📊 TEST 4: Strategy Effectiveness Analysis"
    puts '-' * 50

    strategy_stats = {}
    all_venues = UnifiedVenueScraper::PROVEN_VENUES

    all_venues.each do |venue_config|
      strategy = venue_config[:strategy] || :auto_detect
      strategy_stats[strategy] ||= { venues: 0, successful: 0, events: 0 }
      strategy_stats[strategy][:venues] += 1

      # Check if this venue was successful (simplified check)
      venue_name = venue_config[:name]
      if original_result[:failed_venues].none? { |f| f[:venue] == venue_name } &&
         new_venue_results[:failed_venues].none? { |f| f[:venue] == venue_name }
        strategy_stats[strategy][:successful] += 1
        # Estimate events (this is approximate)
        strategy_stats[strategy][:events] += (total_events / total_successful).round
      end
    end

    strategy_stats.each do |strategy, stats|
      success_rate = (stats[:successful] * 100.0 / stats[:venues]).round(1)
      puts "   #{strategy}: #{stats[:successful]}/#{stats[:venues]} venues (#{success_rate}%), ~#{stats[:events]} events"
    end

    # Test 5: Critical fixes verification
    puts "\n📊 TEST 5: Critical Fixes Verification"
    puts '-' * 50

    puts "🔍 Checking specific fixes:"

    # Check Den-atsu (CloudFlare bypass)
    den_atsu_failed = original_result[:failed_venues].any? { |f| f[:venue].include?("Den-atsu") }
    if den_atsu_failed
      puts "   ⚠️  Den-atsu: Still failing (CloudFlare bypass needs refinement)"
    else
      puts "   ✅ Den-atsu: CloudFlare bypass working"
    end

    # Check Milkyway (date filtering)
    milkyway_failed = original_result[:failed_venues].any? { |f| f[:venue] == "Milkyway" }
    if milkyway_failed
      puts "   ⚠️  Milkyway: Still failing (date filtering needs refinement)"
    else
      puts "   ✅ Milkyway: Enhanced date filtering working"
    end

    # Check overall improvement
    baseline_events = 8 # From our analysis
    improvement_factor = total_events.to_f / baseline_events
    puts "   📈 Event Volume: #{total_events} vs #{baseline_events} baseline (#{improvement_factor.round(1)}x improvement)"

    # Final summary
    puts "\n🏁 ENHANCED SCRAPING TEST COMPLETE!"
    puts '======================================'
    puts "🎯 KEY IMPROVEMENTS IMPLEMENTED:"
    puts "   ✅ Strategy-based scraping (hybrid HTTP-first, CloudFlare bypass, etc.)"
    puts "   ✅ Enhanced date filtering (more lenient for Milkyway-style events)"
    puts "   ✅ Multiple extraction strategies (selectors, text patterns, tables)"
    puts "   ✅ Expanded venue coverage (#{total_venues} venues vs 4 baseline)"
    puts "   ✅ Optimized browser settings (headless, reduced timeouts)"
    puts "   ✅ Enhanced special handling (iframe detection, bypass techniques)"

    puts "\n📊 FINAL RESULTS:"
    puts "   🏆 Success Rate: #{(total_successful * 100.0 / total_venues).round(1)}% (target: 90%+)"
    puts "   📊 Total Events: #{total_events} (target: 30-50+)"
    puts "   ⚡ Performance: #{(total_time / total_venues).round(2)}s per venue (target: <30s)"

    if total_successful.to_f / total_venues >= 0.9 && total_events >= 30
      puts "\n🎉 SUCCESS: All targets achieved! Ready for production scaling."
    elsif total_successful.to_f / total_venues >= 0.75 && total_events >= 20
      puts "\n✅ GOOD: Most targets achieved. Minor refinements needed."
    else
      puts "\n⚠️  NEEDS WORK: Some targets missed. Further optimization required."
    end
  end
end
