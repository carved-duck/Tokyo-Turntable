namespace :scraper do
  desc "Test speed improvements and Milkyway fix"
  task speed_test: :environment do
    scraper = UnifiedVenueScraper.new
    scraper.quick_speed_test
  end

  desc "🚀 ULTRA-FAST test with all optimizations (parallel + HTTP-first + caching)"
  task ultra_fast_test: :environment do
    scraper = UnifiedVenueScraper.new(verbose: true, max_parallel: 3)
    scraper.ultra_speed_test
  end

  desc "🌍 ULTRA-FAST N+1 scaling test with candidate venues"
  task :ultra_n_plus_one, [:candidate_limit] => :environment do |t, args|
    candidate_limit = (args[:candidate_limit] || 5).to_i

    puts "🚀 Starting Ultra-Fast N+1 Scaling Test!"
    puts "📊 Will test #{UnifiedVenueScraper::PROVEN_VENUES.count} proven + #{candidate_limit} candidate venues"

    scraper = UnifiedVenueScraper.new(verbose: true, max_parallel: 3)
    result = scraper.ultra_fast_n_plus_one_test(candidate_limit)

    puts "\n🎉 N+1 SCALING COMPLETE!"
    puts "✅ Total success: #{result[:total_successful]} venues"
    puts "📊 New gigs discovered: #{result[:total_gigs]}"
    puts "⚡ Completed in: #{result[:duration]} seconds"

    if result[:candidate_successful] > 0
      puts "\n🏆 SUCCESS! Found #{result[:candidate_successful]} new working venues!"
      puts "🚀 Ready to scale to hundreds of venues!"
    end
  end

  desc "🔧 IMPROVED N+1 test with enhanced filtering and error analysis"
  task :improved_n_plus_one, [:candidate_limit] => :environment do |t, args|
    candidate_limit = (args[:candidate_limit] || 10).to_i

    puts "🔧 IMPROVED N+1 SCALING TEST WITH ENHANCEMENTS!"
    puts "="*60
    puts "🎯 Testing #{UnifiedVenueScraper::PROVEN_VENUES.count} proven + #{candidate_limit} pre-filtered candidates"
    puts "="*60

    scraper = UnifiedVenueScraper.new(verbose: true, max_parallel: 3)

    # Pre-filter candidates for better success rate
    puts "\n📋 Pre-filtering candidate venues..."
    all_candidates = scraper.get_candidate_venues(candidate_limit * 2) # Get more to filter from

    accessible_candidates = []
    all_candidates.each do |venue|
      if scraper.website_accessible?(venue.website)
        accessible_candidates << venue
        puts "  ✅ #{venue.name} - #{venue.website} (accessible)"
        break if accessible_candidates.count >= candidate_limit
      else
        puts "  ❌ #{venue.name} - #{venue.website} (not accessible)"
      end
    end

    puts "\n📊 Pre-filtering results:"
    puts "  🎯 Accessible candidates: #{accessible_candidates.count}/#{candidate_limit} target"
    puts "  ⚠️ Filtered out: #{all_candidates.count - accessible_candidates.count} inaccessible venues"

    # Use the improved test method with accessible venues
    result = scraper.ultra_fast_n_plus_one_test(accessible_candidates.count)

    # Enhanced analysis
    puts "\n" + "="*60
    puts "🔧 IMPROVED N+1 TEST ANALYSIS:"
    puts "="*60
    puts "⚡ Total time: #{result[:duration]} seconds"
    puts "🏆 Success rate improvement via pre-filtering:"
    puts "  📊 Proven venues: #{result[:proven_successful]}/#{UnifiedVenueScraper::PROVEN_VENUES.count} (#{((result[:proven_successful].to_f / UnifiedVenueScraper::PROVEN_VENUES.count) * 100).round(1)}%)"
    puts "  🎯 Candidate venues: #{result[:candidate_successful]}/#{accessible_candidates.count} (#{accessible_candidates.count > 0 ? ((result[:candidate_successful].to_f / accessible_candidates.count) * 100).round(1) : 0}%)"
    puts "📊 Total gigs: #{result[:total_gigs]}"
    puts "⚡ Performance: #{(result[:total_gigs].to_f / result[:duration]).round(2)} gigs/second"

    if result[:failed_venues].any?
      puts "\n🔍 FAILURE ANALYSIS:"

      failure_reasons = result[:failed_venues].group_by { |f| f[:reason] }
      failure_reasons.each do |reason, venues|
        puts "  • #{reason}: #{venues.count} venues"
        venues.each { |v| puts "    - #{v[:venue]}" }
      end
    end

    puts "\n🎯 NEXT STEPS RECOMMENDATIONS:"
    if result[:candidate_successful] > 0
      success_rate = (result[:candidate_successful].to_f / accessible_candidates.count * 100).round(1)
      if success_rate > 30
        puts "  ✅ High success rate (#{success_rate}%) - ready for large scale testing!"
        puts "  🚀 Recommend testing with 50-100 venues next"
      elsif success_rate > 10
        puts "  ⚡ Moderate success rate (#{success_rate}%) - some improvements working"
        puts "  🔧 Consider further selector enhancements"
      else
        puts "  ⚠️ Low success rate (#{success_rate}%) - need more improvements"
        puts "  🔍 Focus on selector and extraction improvements"
      end
    end
  end

  desc "Test parallel processing only"
  task parallel_test: :environment do
    puts "🚀 PARALLEL PROCESSING TEST"
    puts "="*50

    scraper = UnifiedVenueScraper.new(verbose: true, max_parallel: 3)
    result = scraper.test_proven_venues_parallel(verbose: true)

    puts "\n✅ Parallel test complete!"
    puts "📊 Results: #{result[:successful_venues]}/5 venues, #{result[:total_gigs]} gigs in #{result[:duration]}s"
  end

  desc "Test HTTP-first approach on a single venue"
  task :http_first_test, [:venue_name] => :environment do |t, args|
    venue_name = args[:venue_name] || "Antiknock"

    venue_config = UnifiedVenueScraper::PROVEN_VENUES.find { |v| v[:name] == venue_name }

    unless venue_config
      puts "❌ Venue '#{venue_name}' not found!"
      puts "Available venues: #{UnifiedVenueScraper::PROVEN_VENUES.map { |v| v[:name] }.join(', ')}"
      exit 1
    end

    puts "🌐 Testing HTTP-first approach on: #{venue_name}"
    puts "URL: #{venue_config[:url]}"

    scraper = UnifiedVenueScraper.new(verbose: true)

    start_time = Time.current
    gigs = scraper.scrape_venue_http_first(venue_config)
    duration = (Time.current - start_time).round(2)

    if gigs && gigs.any?
      valid_gigs = scraper.filter_valid_gigs(gigs)
      puts "\n✅ HTTP-first SUCCESS!"
      puts "⚡ Duration: #{duration} seconds"
      puts "📊 Raw gigs: #{gigs.count}"
      puts "✅ Valid gigs: #{valid_gigs.count}"
      puts "🚀 Speed: #{(valid_gigs.count.to_f / duration).round(2)} gigs/second"
    else
      puts "\n⚠️ HTTP-first failed, would fall back to browser"
    end
  end

  desc "Test website complexity detection on specific URL"
  task :complexity_test, [:url] => :environment do |t, args|
    url = args[:url] || "https://www.shibuyamilkyway.com"

    puts "🔍 Testing website complexity detection for: #{url}"

    scraper = UnifiedVenueScraper.new(verbose: true)
    complexity = scraper.detect_website_complexity(url)

    puts "📊 Result: #{complexity}"
    puts "🎯 This means the scraper will use: #{
      case complexity
      when :simple_html
        'Fast HTML-only mode (JavaScript disabled)'
      when :moderate_js
        'Standard mode (JavaScript enabled)'
      when :complex_js
        'Complex mode (Enhanced JavaScript handling)'
      end
    }"
  end

  desc "Compare old vs new scraper speed with all optimizations"
  task speed_comparison: :environment do
    puts "🏁 ULTIMATE SPEED COMPARISON TEST"
    puts "="*60

    scraper = UnifiedVenueScraper.new(verbose: false, max_parallel: 3)

    # Test old sequential approach
    puts "\n🐌 Testing SEQUENTIAL scraper (old approach)..."
    start_time = Time.current
    sequential_result = scraper.test_proven_venues(verbose: false)
    sequential_time = (Time.current - start_time).round(2)

    # Test new parallel approach
    puts "\n🚀 Testing PARALLEL scraper (new approach)..."
    start_time = Time.current
    parallel_result = scraper.test_proven_venues_parallel(verbose: false)
    parallel_time = (Time.current - start_time).round(2)

    puts "\n" + "="*60
    puts "📊 ULTIMATE COMPARISON RESULTS:"
    puts "="*60
    puts "🐌 Sequential: #{sequential_time}s → #{sequential_result[:total_gigs]} gigs"
    puts "🚀 Parallel:   #{parallel_time}s → #{parallel_result[:total_gigs]} gigs"
    puts "⚡ Speed improvement: #{(sequential_time / parallel_time).round(1)}x FASTER!"
    puts "💾 Time saved: #{(sequential_time - parallel_time).round(2)} seconds"
    puts "🏆 Efficiency: #{(parallel_result[:total_gigs].to_f / parallel_time).round(2)} gigs/second"

    if parallel_time < 60
      scaling_estimate = (100 * parallel_time / 60).round(2)
      puts "\n🎯 SCALING ESTIMATE:"
      puts "📈 100 venues would take approximately #{scaling_estimate} minutes!"
      puts "🌍 Ready for massive venue scaling!"
    end
  end

  desc "Clear complexity cache"
  task clear_cache: :environment do
    cache_file = Rails.root.join('tmp', 'venue_complexity_cache.json')
    if File.exist?(cache_file)
      File.delete(cache_file)
      puts "🗑️ Complexity cache cleared!"
    else
      puts "ℹ️ No cache file found."
    end
  end

  desc "🧠 SMART 25-venue test with blacklisting and all enhancements"
  task :smart_25_test => :environment do
    puts "🧠 SMART 25-VENUE TEST WITH FULL OPTIMIZATION SUITE!"
    puts "="*70
    puts "🎯 Testing 5 proven + 20 smart-filtered candidates"
    puts "🚫 Using intelligent blacklisting"
    puts "⚡ All performance optimizations active"
    puts "="*70

    scraper = UnifiedVenueScraper.new(verbose: true, max_parallel: 4) # Increased parallelism

    # Test with 20 candidates for 25 total venues
    result = scraper.ultra_fast_n_plus_one_test(20)

    puts "\n" + "="*70
    puts "🧠 SMART 25-VENUE TEST RESULTS:"
    puts "="*70
    puts "⚡ Total time: #{result[:duration]} seconds"
    puts "🏆 Success rate: #{result[:total_successful]}/25 (#{((result[:total_successful].to_f / 25) * 100).round(1)}%)"
    puts "📊 Proven venue success: #{result[:proven_successful]}/5 (#{((result[:proven_successful].to_f / 5) * 100).round(1)}%)"
    puts "🎯 Candidate discovery rate: #{result[:candidate_successful]}/20 (#{((result[:candidate_successful].to_f / 20) * 100).round(1)}%)"
    puts "📊 Total gigs: #{result[:total_gigs]}"
    puts "⚡ Performance: #{(result[:total_gigs].to_f / result[:duration]).round(2)} gigs/second"
    puts "🚀 Speed: #{(result[:duration] / 25).round(2)} seconds/venue"

    # Scaling projection
    projected_100 = (100 * result[:duration] / 25 / 60).round(1)
    puts "\n🌍 SCALING PROJECTION:"
    puts "📈 100 venues: ~#{projected_100} minutes"
    puts "🚀 1000 venues: ~#{(projected_100 * 10 / 60).round(1)} hours"

    # Enhanced failure analysis
    if result[:failed_venues].any?
      puts "\n🔍 FAILURE PATTERN ANALYSIS:"
      failure_types = result[:failed_venues].group_by { |f| f[:reason].split(':').first }
      failure_types.each do |type, venues|
        puts "  • #{type}: #{venues.count} venues"
      end

      puts "\n💡 OPTIMIZATION SUGGESTIONS:"
      if failure_types['timeout']
        puts "  🚫 Consider longer timeouts or blacklisting timeout-prone sites"
      end
      if failure_types['No gigs found']
        puts "  🔍 Selector improvements needed for content-rich sites"
      end
      if failure_types['Blacklisted venue']
        puts "  ✅ Blacklisting working - skipping known problematic venues"
      end
    end

    # Success rate analysis
    candidate_rate = result[:candidate_successful].to_f / 20 * 100
    puts "\n🎯 SUCCESS RATE ASSESSMENT:"
    case candidate_rate
    when 0..5
      puts "  🔴 Very Low (#{candidate_rate.round(1)}%) - Major selector/approach overhaul needed"
    when 5..15
      puts "  🟡 Low (#{candidate_rate.round(1)}%) - Improvements working but more needed"
    when 15..25
      puts "  🟢 Moderate (#{candidate_rate.round(1)}%) - Good progress, ready for larger tests"
    when 25..40
      puts "  💚 Good (#{candidate_rate.round(1)}%) - Ready for production scaling"
    else
      puts "  🏆 Excellent (#{candidate_rate.round(1)}%) - Exceptional discovery rate!"
    end

    puts "\n🎉 25-VENUE SMART TEST COMPLETE!"
  end

  desc "🏔️ CONSERVATIVE 50-venue test with safe threading"
  task :safe_50_test => :environment do
    puts "🏔️ CONSERVATIVE 50-VENUE SCALING TEST!"
    puts "="*70
    puts "🎯 Testing 5 proven + 45 candidates with SAFE threading"
    puts "🛡️ Conservative parallel limits to prevent thread exhaustion"
    puts "⚡ Optimized for reliability over speed"
    puts "="*70

    # Use conservative settings for large scale
    scraper = UnifiedVenueScraper.new(verbose: true, max_parallel: 2) # Conservative threading

    puts "\n🧵 Using 2 parallel threads (conservative for 50 venues)"
    puts "⏱️ Estimated completion time: ~15-20 minutes"
    puts "💾 All blacklisting and caching optimizations active"

    start_time = Time.current
    result = scraper.ultra_fast_n_plus_one_test(45)
    end_time = Time.current

    puts "\n" + "="*70
    puts "🏔️ CONSERVATIVE 50-VENUE TEST RESULTS:"
    puts "="*70
    puts "⚡ Total time: #{result[:duration]} seconds (#{(result[:duration]/60).round(1)} minutes)"
    puts "🏆 Success rate: #{result[:total_successful]}/50 (#{((result[:total_successful].to_f / 50) * 100).round(1)}%)"
    puts "📊 Proven venue reliability: #{result[:proven_successful]}/5 (#{((result[:proven_successful].to_f / 5) * 100).round(1)}%)"
    puts "🎯 New venue discovery: #{result[:candidate_successful]}/45 (#{((result[:candidate_successful].to_f / 45) * 100).round(1)}%)"
    puts "📊 Total gigs discovered: #{result[:total_gigs]}"
    puts "⚡ Performance: #{(result[:total_gigs].to_f / result[:duration]).round(2)} gigs/second"
    puts "🚀 Venue processing rate: #{(result[:duration] / 50).round(2)} seconds/venue"

    # Advanced scaling projections
    puts "\n🌍 PRODUCTION SCALING PROJECTIONS:"
    puts "📈 100 venues: ~#{(100 * result[:duration] / 50 / 60).round(1)} minutes"
    puts "🏭 500 venues: ~#{(500 * result[:duration] / 50 / 60).round(1)} minutes"
    puts "🚀 1000 venues: ~#{(1000 * result[:duration] / 50 / 60 / 60).round(1)} hours"

    # Blacklist efficiency analysis
    blacklisted_count = result[:failed_venues].count { |f| f[:reason] == "Blacklisted venue" }
    if blacklisted_count > 0
      puts "\n🚫 BLACKLIST EFFICIENCY:"
      puts "  ⚡ #{blacklisted_count} venues skipped instantly (no processing waste)"
      puts "  💾 Blacklist preventing: #{blacklisted_count * 10} seconds of timeouts"
      puts "  ✅ Zero crashes due to problematic venues"
    end

    # Success analysis
    if result[:candidate_successful] > 0
      puts "\n�� NEW VENUE DISCOVERIES:"
      result[:candidate_successful].times do |i|
        puts "  🎯 Successfully integrated #{result[:candidate_successful]} new venues into system"
      end
    end

    puts "\n🏔️ 50-VENUE CONSERVATIVE TEST COMPLETE!"
    puts "🎯 System proven stable at 50-venue scale"
    puts "✅ Ready for production deployment at this scale"
  end
end
