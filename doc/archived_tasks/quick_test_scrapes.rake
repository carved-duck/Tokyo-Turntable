namespace :scrape do
  desc "Quick responsible test - 10 venues in ~5 minutes"
  task :quick_test => :environment do
    puts "⚡ QUICK RESPONSIBLE TEST (10 venues)"
    puts "=" * 50
    puts "⏱️  Estimated time: ~5 minutes"
    puts "🎯 Purpose: Quick validation of scraping accuracy"
    puts ""

    quick_test_venues(10, delay: 2.0)
  end

  desc "Medium test - 25 venues in ~10 minutes"
  task :medium_test => :environment do
    puts "🔬 MEDIUM RESPONSIBLE TEST (25 venues)"
    puts "=" * 50
    puts "⏱️  Estimated time: ~10 minutes"
    puts "🎯 Purpose: Better accuracy sample"
    puts ""

    quick_test_venues(25, delay: 2.0)
  end

  desc "Fast sample - 50 venues in ~15 minutes"
  task :sample_test => :environment do
    puts "📊 SAMPLE TEST (50 venues)"
    puts "=" * 50
    puts "⏱️  Estimated time: ~15 minutes"
    puts "🎯 Purpose: Statistical sample for accuracy assessment"
    puts ""

    quick_test_venues(50, delay: 1.5)
  end

  desc "Speed test - 100 venues with minimal delays (~20 minutes)"
  task :speed_test => :environment do
    puts "🏎️ SPEED TEST (100 venues, minimal delays)"
    puts "=" * 50
    puts "⏱️  Estimated time: ~20 minutes"
    puts "🎯 Purpose: Quick accuracy check with acceptable risk"
    puts ""

    quick_test_venues(100, delay: 1.0)
  end

  desc "Lightning test - just proven venues (~2 minutes)"
  task :lightning_test => :environment do
    puts "⚡ LIGHTNING TEST (proven venues only)"
    puts "=" * 50
    puts "⏱️  Estimated time: ~2 minutes"
    puts "🎯 Purpose: Verify scraping still works"
    puts ""

    test_proven_venues_only
  end

  desc "Accuracy comparison test - compare with your previous 26% baseline"
  task :accuracy_test => :environment do
    puts "🎯 ACCURACY COMPARISON TEST"
    puts "=" * 50
    puts "Comparing current scraping vs your 26% baseline"
    puts "⏱️  Estimated time: ~10 minutes (25 venues)"
    puts ""

    result = quick_test_venues(25, delay: 2.0, compare_accuracy: true)

    puts "\n📈 ACCURACY COMPARISON"
    puts "-" * 30
    puts "Previous baseline: 26% success rate"
    puts "Current test: #{result[:success_rate]}% success rate"

    if result[:success_rate] > 26
      puts "🎉 IMPROVEMENT: +#{(result[:success_rate] - 26).round(1)}% better!"
    elsif result[:success_rate] > 20
      puts "✅ GOOD: Within acceptable range"
    else
      puts "⚠️  CONCERN: Significantly lower than baseline"
    end
  end

  private

  def quick_test_venues(count, delay: 2.0, compare_accuracy: false)
    start_time = Time.current

    # Get a smart sample of venues (mix of proven + candidates)
    proven_venues = get_proven_venue_records.limit(5)
    candidate_venues = get_candidate_venues_sample(count - 5)
    test_venues = (proven_venues + candidate_venues).first(count)

    puts "🔬 Test sample: #{proven_venues.count} proven + #{candidate_venues.count} candidates = #{test_venues.count} total"
    puts ""

    # Create responsible scraper with faster settings
    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 1,
      verbose: true,
      responsible_mode: true,
      rate_limiting: true,
      user_agent: ResponsibleScraperConfig.get_random_user_agent
    )

    total_gigs = 0
    successful_venues = 0
    results = []

    test_venues.each_with_index do |venue, index|
      puts "[#{index + 1}/#{test_venues.count}] #{venue.name}"

      # Quick delay (much faster than full responsible scraping)
      if index > 0
        print "  ⏱️  Quick delay: #{delay}s... "
        sleep(delay)
        puts "✓"
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

          if valid_gigs.any?
            # For testing, don't save to DB to avoid duplicates
            # db_result = scraper.send(:save_gigs_to_database, valid_gigs, venue.name)
            puts "  ✅ Success: #{valid_gigs.length} gigs found"
            total_gigs += valid_gigs.length
            successful_venues += 1

            results << {
              venue: venue.name,
              success: true,
              gigs: valid_gigs.length,
              type: proven_venues.include?(venue) ? 'proven' : 'candidate'
            }
          else
            puts "  ⚠️  Found #{gigs.length} gigs but none current/valid"
            results << { venue: venue.name, success: false, reason: 'no_valid_gigs', type: proven_venues.include?(venue) ? 'proven' : 'candidate' }
          end
        else
          puts "  ❌ No gigs found"
          results << { venue: venue.name, success: false, reason: 'no_gigs', type: proven_venues.include?(venue) ? 'proven' : 'candidate' }
        end

      rescue => e
        puts "  ❌ Error: #{e.message}"
        results << { venue: venue.name, success: false, reason: 'error', error: e.message, type: proven_venues.include?(venue) ? 'proven' : 'candidate' }
      end
    end

    # Results summary
    duration = ((Time.current - start_time) / 1.minute).round(1)
    success_rate = (successful_venues.to_f / test_venues.count * 100).round(1)

    puts "\n🎯 QUICK TEST RESULTS"
    puts "=" * 30
    puts "Duration: #{duration} minutes"
    puts "Venues tested: #{test_venues.count}"
    puts "Successful: #{successful_venues}"
    puts "Success rate: #{success_rate}%"
    puts "Total gigs: #{total_gigs}"
    puts "Avg gigs per successful venue: #{(total_gigs.to_f / successful_venues).round(1)}" if successful_venues > 0

    # Breakdown by type
    proven_results = results.select { |r| r[:type] == 'proven' }
    candidate_results = results.select { |r| r[:type] == 'candidate' }

    puts "\n📊 BREAKDOWN"
    puts "-" * 20
    if proven_results.any?
      proven_success = proven_results.count { |r| r[:success] }
      puts "Proven venues: #{proven_success}/#{proven_results.count} (#{(proven_success.to_f / proven_results.count * 100).round(1)}%)"
    end

    if candidate_results.any?
      candidate_success = candidate_results.count { |r| r[:success] }
      puts "Candidate venues: #{candidate_success}/#{candidate_results.count} (#{(candidate_success.to_f / candidate_results.count * 100).round(1)}%)"
    end

    if compare_accuracy
      puts "\n🔍 TOP PERFORMING VENUES"
      puts "-" * 25
      successful_results = results.select { |r| r[:success] && r[:gigs] }
                                  .sort_by { |r| -r[:gigs] }
                                  .first(5)

      successful_results.each do |result|
        puts "#{result[:venue]}: #{result[:gigs]} gigs (#{result[:type]})"
      end
    end

    {
      success_rate: success_rate,
      total_gigs: total_gigs,
      duration_minutes: duration,
      successful_venues: successful_venues,
      results: results
    }
  end

  def test_proven_venues_only
    start_time = Time.current

    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 1,
      verbose: true,
      responsible_mode: true
    )

    proven_venues = UnifiedVenueScraper::PROVEN_VENUES
    total_gigs = 0
    successful_venues = 0

    proven_venues.each_with_index do |venue_config, index|
      puts "[#{index + 1}/#{proven_venues.length}] #{venue_config[:name]}"

      sleep(1) if index > 0  # Very quick delay for lightning test

      begin
        gigs = scraper.scrape_venue_optimized(venue_config)

        if gigs&.any?
          valid_gigs = scraper.filter_valid_gigs(gigs)
          if valid_gigs.any?
            puts "  ✅ Success: #{valid_gigs.length} gigs"
            total_gigs += valid_gigs.length
            successful_venues += 1
          else
            puts "  ⚠️  No valid current gigs"
          end
        else
          puts "  ❌ No gigs found"
        end
      rescue => e
        puts "  ❌ Error: #{e.message}"
      end
    end

    duration = ((Time.current - start_time) / 1.minute).round(1)

    puts "\n⚡ LIGHTNING TEST COMPLETE"
    puts "-" * 25
    puts "Duration: #{duration} minutes"
    puts "Successful: #{successful_venues}/#{proven_venues.length}"
    puts "Total gigs: #{total_gigs}"
    puts "Proven venues working: #{successful_venues >= 4 ? '✅ YES' : '❌ NO'}"
  end

  def get_proven_venue_records
    proven_names = UnifiedVenueScraper::PROVEN_VENUES.map { |v| v[:name] }
    Venue.where(name: proven_names)
  end

  def get_candidate_venues_sample(count)
    # Get a diverse sample of candidate venues
    Venue.where.not(website: [nil, ''])
         .where("website NOT LIKE '%facebook%'")
         .where("website NOT LIKE '%instagram%'")
         .where("website NOT LIKE '%twitter%'")
         .where.not(name: UnifiedVenueScraper::PROVEN_VENUES.map { |v| v[:name] })
         .order('RANDOM()')  # Random sample for better testing
         .limit(count)
  end
end
