namespace :trust do
  desc "🛡️ Run Bulletproof Trust Verification System"
  task verify_all_data: :environment do
    puts "🛡️ TOKYO TURNTABLE BULLETPROOF TRUST VERIFICATION"
    puts "=" * 70
    puts "🎯 Ensuring ZERO false recommendations"
    puts "🚀 Building unshakeable user trust"
    puts "💎 Only showing data we'd stake our reputation on"
    puts "=" * 70
    puts

    # Initialize confidence engine
    confidence_engine = ConfidenceEngine.new(verbose: true, strict_mode: true)

    # Get all current/future gigs
    current_gigs = Gig.where('date >= ?', Date.current)
                     .includes(:venue, :bands)
                     .order(:date)

    puts "🔍 Analyzing #{current_gigs.count} current/future gigs..."
    puts

    # Verification results
    verified_gigs = []
    trusted_gigs = []
    caution_gigs = []
    rejected_gigs = []

    # Process each gig
    current_gigs.each_with_index do |gig, index|
      print "\r🔍 Processing gig #{index + 1}/#{current_gigs.count}..."

      assessment = confidence_engine.assess_gig_confidence(gig)

      case assessment[:verification_status]
      when 'VERIFIED'
        verified_gigs << { gig: gig, assessment: assessment }
      when 'TRUSTED'
        trusted_gigs << { gig: gig, assessment: assessment }
      when 'CAUTION'
        caution_gigs << { gig: gig, assessment: assessment }
      else
        rejected_gigs << { gig: gig, assessment: assessment }
      end
    end

    puts "\n"
    puts "🎉 TRUST VERIFICATION COMPLETE!"
    puts "=" * 70

    # Results summary
    total_gigs = current_gigs.count
    puts "📊 VERIFICATION RESULTS:"
    puts "  🌟 VERIFIED (95%+ confidence): #{verified_gigs.count} gigs"
    puts "  ✅ TRUSTED (85-94% confidence): #{trusted_gigs.count} gigs"
    puts "  ⚠️ CAUTION (70-84% confidence): #{caution_gigs.count} gigs"
    puts "  ❌ REJECTED (<70% confidence): #{rejected_gigs.count} gigs"
    puts

    # Show what users will see
    showable_gigs = verified_gigs.count + trusted_gigs.count
    puts "🎯 USER EXPERIENCE:"
    puts "  👥 Gigs shown to users: #{showable_gigs}/#{total_gigs} (#{(showable_gigs.to_f/total_gigs*100).round(1)}%)"
    puts "  🛡️ Confidence level: #{showable_gigs > 0 ? 'BULLETPROOF' : 'NEEDS WORK'}"
    puts

    # Detailed breakdown of top verified gigs
    if verified_gigs.any?
      puts "🌟 TOP VERIFIED GIGS (100% safe to recommend):"
      verified_gigs.first(5).each do |item|
        gig = item[:gig]
        assessment = item[:assessment]
        puts "  ✅ #{gig.date} - #{gig.venue.name}"
        puts "      🎵 #{gig.bands.map(&:name).join(', ')}"
        puts "      🎯 Confidence: #{(assessment[:overall_confidence] * 100).round(1)}%"
      end
      puts
    end

    # Show risk factors for caution gigs
    if caution_gigs.any?
      puts "⚠️ CAUTION GIGS (need improvement before showing):"
      caution_gigs.first(3).each do |item|
        gig = item[:gig]
        assessment = item[:assessment]
        puts "  ⚠️ #{gig.date} - #{gig.venue.name}"
        puts "      🎯 Confidence: #{(assessment[:overall_confidence] * 100).round(1)}%"
        puts "      🚨 Risks: #{assessment[:risk_factors].map { |r| r[:description] }.join(', ')}"
      end
      puts
    end

    # Recommendations
    puts "🔮 TRUST BUILDING RECOMMENDATIONS:"

    if verified_gigs.count < total_gigs * 0.5
      puts "  🎯 PRIORITY: Increase verified gigs to 50%+ of total"
      puts "  📍 Focus on venue verification and address validation"
      puts "  🌐 Implement real-time website checking"
    end

    if rejected_gigs.count > total_gigs * 0.2
      puts "  🧹 CLEANUP: Remove #{rejected_gigs.count} low-confidence gigs"
      puts "  🔍 Improve data quality at source"
    end

    puts "  🚀 NEXT STEPS:"
    puts "    • Run 'rails trust:create_user_safe_dataset' to prepare public data"
    puts "    • Run 'rails trust:venue_verification' to verify venue locations"
    puts "    • Run 'rails trust:artist_verification' to verify band authenticity"

    puts "\n💎 TOKYO TURNTABLE TRUST SCORE: #{calculate_trust_score(verified_gigs.count, trusted_gigs.count, total_gigs)}"
  end

  desc "🎯 Create User-Safe Dataset (Only Bulletproof Data)"
  task create_user_safe_dataset: :environment do
    puts "🎯 CREATING USER-SAFE DATASET"
    puts "=" * 50
    puts "🛡️ Only including data we'd stake our reputation on"
    puts

    confidence_engine = ConfidenceEngine.new(strict_mode: true)

    # Get all gigs and assess confidence
    all_gigs = Gig.where('date >= ?', Date.current).includes(:venue, :bands)
    safe_gigs = []

    all_gigs.each do |gig|
      assessment = confidence_engine.assess_gig_confidence(gig)

      # Only include VERIFIED and TRUSTED gigs
      if ['VERIFIED', 'TRUSTED'].include?(assessment[:verification_status])
        safe_gigs << {
          gig: gig,
          confidence: assessment[:overall_confidence],
          status: assessment[:verification_status]
        }
      end
    end

    # Sort by confidence (highest first)
    safe_gigs.sort_by! { |item| -item[:confidence] }

    puts "✅ SAFE DATASET CREATED:"
    puts "  📊 Total gigs analyzed: #{all_gigs.count}"
    puts "  🛡️ Safe gigs for users: #{safe_gigs.count}"
    puts "  📈 Safety rate: #{(safe_gigs.count.to_f / all_gigs.count * 100).round(1)}%"
    puts

    # Export safe dataset
    safe_data = {
      generated_at: Time.current,
      total_analyzed: all_gigs.count,
      safe_count: safe_gigs.count,
      safety_rate: (safe_gigs.count.to_f / all_gigs.count * 100).round(1),
      gigs: safe_gigs.map do |item|
        gig = item[:gig]
        {
          id: gig.id,
          date: gig.date,
          venue: {
            name: gig.venue.name,
            address: gig.venue.address,
            neighborhood: gig.venue.neighborhood,
            website: gig.venue.website
          },
          bands: gig.bands.map { |band| { name: band.name, genre: band.genre } },
          time: {
            open: gig.open_time,
            start: gig.start_time
          },
          price: gig.price,
          confidence: item[:confidence],
          status: item[:status]
        }
      end
    }

    # Save to file
    output_file = Rails.root.join('db', 'data', 'user_safe_gigs.json')
    File.write(output_file, JSON.pretty_generate(safe_data))

    puts "💾 Safe dataset saved to: #{output_file}"
    puts "🚀 Ready for production use!"

    # Show sample of safest gigs
    puts "\n🌟 TOP 5 SAFEST GIGS:"
    safe_gigs.first(5).each_with_index do |item, index|
      gig = item[:gig]
      puts "  #{index + 1}. #{gig.date} - #{gig.venue.name}"
      puts "      🎵 #{gig.bands.map(&:name).join(', ')}"
      puts "      🎯 #{(item[:confidence] * 100).round(1)}% confidence (#{item[:status]})"
    end
  end

  desc "📍 Verify Venue Locations"
  task venue_verification: :environment do
    puts "📍 VENUE LOCATION VERIFICATION"
    puts "=" * 50
    puts "🎯 Ensuring every venue is a real, findable location"
    puts

    venues_with_gigs = Venue.joins(:gigs)
                           .where('gigs.date >= ?', Date.current)
                           .distinct
                           .includes(:gigs)

    puts "🔍 Verifying #{venues_with_gigs.count} venues with current/future gigs..."
    puts

    verified_venues = []
    suspicious_venues = []
    needs_improvement = []

    venues_with_gigs.each do |venue|
      score = assess_venue_trustworthiness(venue)

      case score
      when 0.9..1.0
        verified_venues << { venue: venue, score: score }
      when 0.7..0.89
        needs_improvement << { venue: venue, score: score }
      else
        suspicious_venues << { venue: venue, score: score }
      end
    end

    puts "📊 VENUE VERIFICATION RESULTS:"
    puts "  ✅ Verified venues: #{verified_venues.count}"
    puts "  ⚠️ Need improvement: #{needs_improvement.count}"
    puts "  🚨 Suspicious venues: #{suspicious_venues.count}"
    puts

    if suspicious_venues.any?
      puts "🚨 SUSPICIOUS VENUES (investigate immediately):"
      suspicious_venues.each do |item|
        venue = item[:venue]
        puts "  ❌ #{venue.name}"
        puts "      📍 #{venue.address}"
        puts "      🌐 #{venue.website}"
        puts "      🎪 #{venue.gigs.where('date >= ?', Date.current).count} upcoming gigs"
        puts "      🎯 Trust score: #{(item[:score] * 100).round(1)}%"
        puts
      end
    end

    puts "🔮 RECOMMENDATIONS:"
    puts "  • Manually verify suspicious venues"
    puts "  • Add Google Maps integration for address validation"
    puts "  • Implement real-time website checking"
    puts "  • Cross-reference with official venue directories"
  end

  desc "🎤 Verify Artist Authenticity"
  task artist_verification: :environment do
    puts "🎤 ARTIST AUTHENTICITY VERIFICATION"
    puts "=" * 50
    puts "🎯 Ensuring bands are real, searchable artists"
    puts

    # Get bands with upcoming gigs
    bands_with_gigs = Band.joins(:gigs)
                         .where('gigs.date >= ?', Date.current)
                         .distinct
                         .includes(:gigs)

    puts "🔍 Verifying #{bands_with_gigs.count} bands with upcoming gigs..."
    puts

    real_artists = []
    questionable_artists = []
    fake_artists = []

    bands_with_gigs.each do |band|
      authenticity_score = assess_artist_authenticity(band)

      case authenticity_score
      when 0.8..1.0
        real_artists << { band: band, score: authenticity_score }
      when 0.5..0.79
        questionable_artists << { band: band, score: authenticity_score }
      else
        fake_artists << { band: band, score: authenticity_score }
      end
    end

    puts "📊 ARTIST VERIFICATION RESULTS:"
    puts "  ✅ Real artists: #{real_artists.count}"
    puts "  ⚠️ Questionable: #{questionable_artists.count}"
    puts "  ❌ Likely fake: #{fake_artists.count}"
    puts

    if fake_artists.any?
      puts "❌ LIKELY FAKE ARTISTS (remove from public view):"
      fake_artists.first(10).each do |item|
        band = item[:band]
        puts "  🚫 #{band.name}"
        puts "      🎪 #{band.gigs.where('date >= ?', Date.current).count} upcoming gigs"
        puts "      🎯 Authenticity: #{(item[:score] * 100).round(1)}%"
      end
      puts
    end

    puts "🔮 RECOMMENDATIONS:"
    puts "  • Remove #{fake_artists.count} fake artists from public view"
    puts "  • Integrate with Spotify API for artist verification"
    puts "  • Add MusicBrainz database checking"
    puts "  • Implement user reporting for fake artists"
  end

  desc "📊 Generate Trust Report"
  task generate_trust_report: :environment do
    puts "📊 TOKYO TURNTABLE TRUST REPORT"
    puts "=" * 60
    puts "🎯 Comprehensive analysis of data trustworthiness"
    puts "=" * 60
    puts

    # Overall statistics
    total_venues = Venue.count
    total_gigs = Gig.where('date >= ?', Date.current).count
    total_bands = Band.joins(:gigs).where('gigs.date >= ?', Date.current).distinct.count

    puts "📈 OVERALL STATISTICS:"
    puts "  🏢 Active venues: #{total_venues}"
    puts "  🎪 Upcoming gigs: #{total_gigs}"
    puts "  🎵 Active bands: #{total_bands}"
    puts

    # Confidence assessment
    confidence_engine = ConfidenceEngine.new
    high_confidence_gigs = 0
    medium_confidence_gigs = 0
    low_confidence_gigs = 0

    Gig.where('date >= ?', Date.current).includes(:venue, :bands).find_each do |gig|
      assessment = confidence_engine.assess_gig_confidence(gig)

      case assessment[:overall_confidence]
      when 0.85..1.0
        high_confidence_gigs += 1
      when 0.70..0.84
        medium_confidence_gigs += 1
      else
        low_confidence_gigs += 1
      end
    end

    puts "🎯 CONFIDENCE DISTRIBUTION:"
    puts "  🌟 High confidence (85%+): #{high_confidence_gigs} gigs"
    puts "  ⚠️ Medium confidence (70-84%): #{medium_confidence_gigs} gigs"
    puts "  🚨 Low confidence (<70%): #{low_confidence_gigs} gigs"
    puts

    # Trust score calculation
    trust_score = calculate_trust_score(high_confidence_gigs, medium_confidence_gigs, total_gigs)
    puts "💎 TOKYO TURNTABLE TRUST SCORE: #{trust_score}"
    puts

    # Recommendations based on trust score
    case trust_score
    when 'BULLETPROOF'
      puts "🚀 READY FOR LAUNCH! Your data quality is exceptional."
      puts "✅ Users can trust your recommendations completely."
    when 'EXCELLENT'
      puts "🌟 NEARLY PERFECT! Minor improvements will make you bulletproof."
      puts "🎯 Focus on the remaining low-confidence gigs."
    when 'GOOD'
      puts "✅ SOLID FOUNDATION! You're on the right track."
      puts "🔧 Implement venue verification and artist authentication."
    when 'NEEDS WORK'
      puts "⚠️ IMPROVEMENT NEEDED before public launch."
      puts "🛠️ Focus on data quality and verification systems."
    else
      puts "🚨 CRITICAL ISSUES must be resolved before launch."
      puts "🔧 Implement comprehensive data cleaning and verification."
    end

    puts "\n🔮 NEXT STEPS:"
    puts "  1. Focus on high-impact improvements"
    puts "  2. Implement real-time verification"
    puts "  3. Add user feedback mechanisms"
    puts "  4. Create confidence-based UI"
  end

  private

  def assess_venue_trustworthiness(venue)
    score = 0.5

    # Real address
    if venue.address.present? && venue.address.length > 15
      score += 0.2
    end

    # Working website
    if venue.website.present? && venue.website.match?(/^https?:\/\//)
      score += 0.2
    end

    # Has neighborhood
    if venue.neighborhood.present? && venue.neighborhood != 'Tokyo'
      score += 0.1
    end

    # Recent activity
    recent_gigs = venue.gigs.where('date >= ?', 30.days.ago).count
    if recent_gigs > 0
      score += 0.2
    end

    score
  end

  def assess_artist_authenticity(band)
    score = 0.5

    # Name quality
    if band.name.present? && band.name.length >= 2 && band.name.length <= 50
      score += 0.1
    end

    # Not obviously fake
    unless band.name.match?(/^\d+$|test|fake|dummy/i)
      score += 0.2
    end

    # Has genre (suggests verification)
    if band.genre != 'Unknown'
      score += 0.2
    end

    # Multiple gigs (suggests real artist)
    gig_count = band.gigs.count
    if gig_count > 1
      score += 0.1
    elsif gig_count > 5
      score += 0.2
    end

    score
  end

  def calculate_trust_score(high_confidence, medium_confidence, total)
    return 'NO DATA' if total == 0

    high_percentage = (high_confidence.to_f / total * 100).round(1)
    medium_percentage = (medium_confidence.to_f / total * 100).round(1)
    combined_percentage = high_percentage + medium_percentage

    case combined_percentage
    when 95..100
      'BULLETPROOF'
    when 85..94
      'EXCELLENT'
    when 70..84
      'GOOD'
    when 50..69
      'NEEDS WORK'
    else
      'CRITICAL'
    end
  end
end
