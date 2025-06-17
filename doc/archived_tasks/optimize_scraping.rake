namespace :scraping do
  desc "Optimize core venue scraping for production readiness"
  task optimize: :environment do
    puts "🎯 SCRAPING OPTIMIZATION FOR FRIDAY SHIP"
    puts "=" * 50

    puts "\n📊 Current Database Status:"
    puts "  Total venues: #{Venue.count}"
    puts "  Venues with gigs: #{Venue.joins(:gigs).distinct.count}"
    puts "  Total gigs: #{Gig.count}"
    puts "  Gigs with bands: #{Gig.joins(:bands).distinct.count}"

    # Test proven venues to ensure quality
    puts "\n🧪 Testing Proven Venues Quality..."
    scraper = UnifiedVenueScraper.new(verbose: true)
    results = scraper.test_proven_venues

    puts "\n📋 QUALITY ASSESSMENT:"
    puts "  ✅ Working venues: #{results[:successful_venues]}/4"
    puts "  📊 Total gigs found: #{results[:total_gigs]}"

    if results[:failed_venues].any?
      puts "  ❌ Failed venues:"
      results[:failed_venues].each do |failure|
        puts "    - #{failure[:venue]}: #{failure[:reason]}"
      end
    end

    # Check gig data quality
    puts "\n🔍 Analyzing Gig Data Quality..."

    recent_gigs = Gig.joins(:venue).where('date >= ?', Date.current).includes(:bands, :venue)

    quality_metrics = {
      gigs_with_dates: recent_gigs.where.not(date: nil).count,
      gigs_with_times: recent_gigs.where.not(start_time: nil).count,
      gigs_with_bands: recent_gigs.joins(:bands).distinct.count,
      gigs_with_prices: recent_gigs.where.not(price: [nil, '', 'TBA', 'TBD']).count,
      gigs_with_venues: recent_gigs.joins(:venue).count
    }

    total_recent = recent_gigs.count

    puts "  📅 Dates: #{quality_metrics[:gigs_with_dates]}/#{total_recent} (#{((quality_metrics[:gigs_with_dates].to_f / [total_recent, 1].max) * 100).round(1)}%)"
    puts "  ⏰ Times: #{quality_metrics[:gigs_with_times]}/#{total_recent} (#{((quality_metrics[:gigs_with_times].to_f / [total_recent, 1].max) * 100).round(1)}%)"
    puts "  🎵 Bands: #{quality_metrics[:gigs_with_bands]}/#{total_recent} (#{((quality_metrics[:gigs_with_bands].to_f / [total_recent, 1].max) * 100).round(1)}%)"
    puts "  💰 Prices: #{quality_metrics[:gigs_with_prices]}/#{total_recent} (#{((quality_metrics[:gigs_with_prices].to_f / [total_recent, 1].max) * 100).round(1)}%)"
    puts "  🏢 Venues: #{quality_metrics[:gigs_with_venues]}/#{total_recent} (#{((quality_metrics[:gigs_with_venues].to_f / [total_recent, 1].max) * 100).round(1)}%)"

    # Recommendations for production
    puts "\n💡 FRIDAY SHIP READINESS:"

    readiness_score = 0
    max_score = 5

    if results[:successful_venues] >= 3
      puts "  ✅ Core venues working (#{results[:successful_venues]}/4)"
      readiness_score += 1
    else
      puts "  ❌ Need at least 3 core venues working"
    end

    if quality_metrics[:gigs_with_dates].to_f / [total_recent, 1].max >= 0.8
      puts "  ✅ Good date coverage (#{((quality_metrics[:gigs_with_dates].to_f / [total_recent, 1].max) * 100).round(1)}%)"
      readiness_score += 1
    else
      puts "  ⚠️  Date coverage could improve"
    end

    if quality_metrics[:gigs_with_bands].to_f / [total_recent, 1].max >= 0.7
      puts "  ✅ Good band associations (#{((quality_metrics[:gigs_with_bands].to_f / [total_recent, 1].max) * 100).round(1)}%)"
      readiness_score += 1
    else
      puts "  ⚠️  Band coverage could improve"
    end

    if total_recent >= 20
      puts "  ✅ Sufficient gig volume (#{total_recent} gigs)"
      readiness_score += 1
    else
      puts "  ⚠️  Need more gigs for launch"
    end

    if Venue.joins(:gigs).distinct.count >= 4
      puts "  ✅ Multiple venues with content"
      readiness_score += 1
    else
      puts "  ⚠️  Need more active venues"
    end

    puts "\n🎯 READINESS SCORE: #{readiness_score}/#{max_score}"

    if readiness_score >= 4
      puts "  🚀 READY FOR FRIDAY SHIP!"
    elsif readiness_score >= 3
      puts "  ⚠️  Almost ready - minor improvements needed"
    else
      puts "  ❌ Need significant improvements before shipping"
    end

    puts "\n📋 RECOMMENDED ACTIONS:"
    if results[:failed_venues].any?
      puts "  1. Fix failed venues: #{results[:failed_venues].map { |f| f[:venue] }.join(', ')}"
    end
    puts "  2. Run regular scraping: rails recurring:all"
    puts "  3. Test user flows with current data"
    puts "  4. Monitor scraping logs for errors"

    puts "\n✅ Optimization analysis complete!"
  end

  desc "Quick quality check for all venues with gigs"
  task quality_check: :environment do
    puts "🔍 QUICK QUALITY CHECK"
    puts "=" * 30

    venues_with_gigs = Venue.joins(:gigs).includes(:gigs).distinct

    venues_with_gigs.each do |venue|
      recent_gigs = venue.gigs.where('date >= ?', Date.current)

      puts "\n🏢 #{venue.name}:"
      puts "  📊 #{recent_gigs.count} upcoming gigs"

      if recent_gigs.any?
        quality_issues = []

        missing_dates = recent_gigs.where(date: nil).count
        missing_times = recent_gigs.where(start_time: nil).count
        missing_bands = recent_gigs.left_joins(:bands).where(bands: { id: nil }).count

        quality_issues << "#{missing_dates} missing dates" if missing_dates > 0
        quality_issues << "#{missing_times} missing times" if missing_times > 0
        quality_issues << "#{missing_bands} missing bands" if missing_bands > 0

        if quality_issues.any?
          puts "  ⚠️  Issues: #{quality_issues.join(', ')}"
        else
          puts "  ✅ Quality looks good"
        end

        # Show sample
        sample_gig = recent_gigs.first
        if sample_gig
          puts "  📅 Sample: #{sample_gig.date} - #{sample_gig.bands.first&.name || 'No band'}"
        end
      end
    end

    puts "\n✅ Quality check complete!"
  end
end
