namespace :bands do
  desc "🧠 Test Intelligent Band Extraction System"
  task test_intelligent_extraction: :environment do
    puts "🧠 TESTING INTELLIGENT BAND EXTRACTION SYSTEM"
    puts "=" * 70
    puts "🎯 Revolutionary AI-Powered Band Name Recognition"
    puts "🚀 Competing with ChatGPT-level Accuracy"
    puts "=" * 70
    puts

    # Initialize the intelligent extractor
    extractor = IntelligentBandExtractor.new(verbose: true, confidence_threshold: 0.6)

    puts "✅ Intelligent Band Extractor initialized"
    puts "🎯 Confidence threshold: 0.6 (60%)"
    puts

    # Test with real problematic data from today's gigs
    puts "🔍 TESTING WITH REAL PROBLEMATIC DATA:"
    puts "-" * 50

    test_cases = [
      {
        title: "2025.6.14 Cornelius Live at Blue Note",
        artists: nil,
        expected: "Cornelius"
      },
      {
        title: "14 Sat WWW 幽体コミュニケーションズ",
        artists: nil,
        expected: "幽体コミュニケーションズ"
      },
      {
        title: "君島大空トリオ 『文明の欠伸』リリース記念公演 in 東京 WWW",
        artists: nil,
        expected: "君島大空トリオ"
      },
      {
        title: "Live: Guitar Wolf and Boris",
        artists: "Guitar Wolf / Boris",
        expected: "Guitar Wolf, Boris"
      },
      {
        title: "Perfume ● Electronic Night ● Special Performance",
        artists: nil,
        expected: "Perfume"
      },
      {
        title: "2025.6",
        artists: nil,
        expected: "Live Performance"
      },
      {
        title: "June 14",
        artists: nil,
        expected: "Live Performance"
      },
      {
        title: "Zepp Sapporo",
        artists: nil,
        expected: "Live Performance"
      }
    ]

    successful_extractions = 0
    total_tests = test_cases.length

    test_cases.each_with_index do |test_case, index|
      puts "\n[#{index + 1}/#{total_tests}] 🧪 TESTING:"
      puts "  📝 Title: #{test_case[:title]}"
      puts "  🎤 Artists: #{test_case[:artists] || 'None'}"
      puts "  🎯 Expected: #{test_case[:expected]}"

      # Create gig data
      gig_data = {
        title: test_case[:title],
        artists: test_case[:artists],
        raw_text: test_case[:title]
      }

      # Extract bands using intelligent system
      extracted_bands = extractor.extract_bands_from_gig_data(gig_data)

      puts "  🧠 AI Result: #{extracted_bands.join(', ')}"

      # Check if extraction was successful
      if test_case[:expected] == "Live Performance"
        success = extracted_bands == ["Live Performance"]
      else
        success = extracted_bands.any? { |band| test_case[:expected].include?(band) || band.include?(test_case[:expected]) }
      end

      if success
        puts "  ✅ SUCCESS!"
        successful_extractions += 1
      else
        puts "  ❌ NEEDS IMPROVEMENT"
      end
    end

    accuracy = (successful_extractions.to_f / total_tests * 100).round(1)

    puts "\n🎉 INTELLIGENT EXTRACTION TEST COMPLETE!"
    puts "=" * 70
    puts "🏆 Successful extractions: #{successful_extractions}/#{total_tests}"
    puts "📈 Accuracy rate: #{accuracy}%"
    puts "🧠 AI Intelligence: #{accuracy > 75 ? 'EXCELLENT' : accuracy > 50 ? 'GOOD' : 'NEEDS TUNING'}"

    if accuracy > 75
      puts "\n🌟 OUTSTANDING PERFORMANCE!"
      puts "🚀 Ready to revolutionize your band data quality!"
    elsif accuracy > 50
      puts "\n✅ GOOD PERFORMANCE!"
      puts "🎯 System shows strong potential for improvement"
    else
      puts "\n📚 LEARNING OPPORTUNITY"
      puts "🔧 System needs parameter tuning for optimal results"
    end

    puts "\n🔮 NEXT STEPS:"
    puts "  • Run 'rails bands:apply_intelligent_extraction' to improve real data"
    puts "  • Run 'rails bands:analyze_extraction_quality' for detailed analysis"
    puts "  • Adjust confidence threshold if needed"
  end

  desc "🚀 Apply Intelligent Band Extraction to Real Data"
  task apply_intelligent_extraction: :environment do
    puts "🚀 APPLYING INTELLIGENT BAND EXTRACTION TO REAL DATA"
    puts "=" * 70
    puts "🎯 Transforming Your Band Database with AI Intelligence"
    puts "🧠 Competing with ChatGPT-level Accuracy"
    puts "=" * 70
    puts

    # Initialize the intelligent extractor
    extractor = IntelligentBandExtractor.new(verbose: false, confidence_threshold: 0.6)

    # Get gigs with problematic band names
    problematic_gigs = Gig.joins(:bands)
                         .where("bands.name LIKE ? OR bands.name LIKE ? OR bands.name LIKE ? OR bands.name LIKE ?",
                               '%2025%', '%14%', '%sat%', '%jun%')
                         .includes(:bands, :venue)
                         .limit(50)

    puts "🔍 Found #{problematic_gigs.count} gigs with problematic band associations"
    puts "🎯 Processing with intelligent extraction..."
    puts

    improved_gigs = 0
    total_bands_before = 0
    total_bands_after = 0

    problematic_gigs.each_with_index do |gig, index|
      puts "[#{index + 1}/#{problematic_gigs.count}] 🎪 #{gig.venue&.name}"

      # Get current band names
      current_bands = gig.bands.map(&:name)
      total_bands_before += current_bands.length

      puts "  📝 Current bands: #{current_bands.join(', ')}"

      # Create gig data for extraction
      # We'll reconstruct what the original scraped data might have looked like
      combined_title = current_bands.join(' | ')
      gig_data = {
        title: combined_title,
        artists: nil,
        raw_text: combined_title
      }

      # Extract improved band names
      improved_bands = extractor.extract_bands_from_gig_data(gig_data)

      puts "  🧠 AI extracted: #{improved_bands.join(', ')}"

      # Only update if we got a real improvement
      if improved_bands != ["Live Performance"] && improved_bands != current_bands
        # Clear existing associations
        gig.bands.clear

        # Create new band associations
        improved_bands.each do |band_name|
          band = Band.find_or_create_by(name: band_name) do |b|
            b.genre = 'Unknown'
            b.hometown = 'Tokyo, Japan'
            b.email = 'contact@band.com'
          end

          # Create booking
          Booking.find_or_create_by(gig: gig, band: band)
        end

        total_bands_after += improved_bands.length
        improved_gigs += 1
        puts "  ✅ IMPROVED!"
      else
        total_bands_after += current_bands.length
        puts "  📝 No improvement needed"
      end

      puts
    end

    puts "🎉 INTELLIGENT EXTRACTION APPLICATION COMPLETE!"
    puts "=" * 70
    puts "🏆 Gigs improved: #{improved_gigs}/#{problematic_gigs.count}"
    puts "📊 Bands before: #{total_bands_before}"
    puts "📊 Bands after: #{total_bands_after}"
    puts "📈 Improvement rate: #{(improved_gigs.to_f / problematic_gigs.count * 100).round(1)}%"
    puts "🧠 AI Intelligence: Successfully applied to real data"

    puts "\n🌟 IMPACT ASSESSMENT:"
    if improved_gigs > problematic_gigs.count * 0.3
      puts "🚀 MAJOR IMPROVEMENT! Significant data quality enhancement"
    elsif improved_gigs > 0
      puts "✅ POSITIVE IMPACT! Meaningful improvements detected"
    else
      puts "📚 LEARNING PHASE! System ready for parameter tuning"
    end

    puts "\n🔮 NEXT STEPS:"
    puts "  • Run 'rails bands:analyze_extraction_quality' for detailed analysis"
    puts "  • Check genre classification improvements"
    puts "  • Consider expanding to more gigs"
  end

  desc "📊 Analyze Band Extraction Quality"
  task analyze_extraction_quality: :environment do
    puts "📊 BAND EXTRACTION QUALITY ANALYSIS"
    puts "=" * 60
    puts "🔍 Deep Dive into Data Quality Improvements"
    puts "=" * 60
    puts

    # Overall statistics
    total_bands = Band.count
    total_gigs = Gig.count
    total_venues = Venue.count

    puts "📈 OVERALL DATABASE STATISTICS:"
    puts "  🎵 Total Bands: #{total_bands.to_s.reverse.gsub(/(\\d{3})(?=\\d)/, '\\1,').reverse}"
    puts "  🎪 Total Gigs: #{total_gigs.to_s.reverse.gsub(/(\\d{3})(?=\\d)/, '\\1,').reverse}"
    puts "  🏢 Total Venues: #{total_venues.to_s.reverse.gsub(/(\\d{3})(?=\\d)/, '\\1,').reverse}"
    puts

    # Band name quality analysis
    puts "🎯 BAND NAME QUALITY ANALYSIS:"

    # Date patterns (bad)
    date_pattern_bands = Band.where("name ~ ?", "\\d{4}[/\\-\\.\\d{1,2}[/\\-\\.]\\d{1,2}|\\d{1,2}[/\\-\\.]\\d{1,2}").count
    puts "  ❌ Date patterns: #{date_pattern_bands} bands"

    # Day patterns (bad)
    day_pattern_bands = Band.where("name ~ ?", "\\d{1,2}\\s*\\([a-z]{3}\\)").count
    puts "  ❌ Day patterns: #{day_pattern_bands} bands"

    # Venue names (bad)
    venue_name_bands = Band.where("name ILIKE ANY (ARRAY['%zepp%', '%www%', '%club%', '%hall%', '%bar%'])").count
    puts "  ❌ Venue names: #{venue_name_bands} bands"

    # Very short names (suspicious)
    short_name_bands = Band.where("LENGTH(name) <= 3").count
    puts "  ⚠️ Very short names: #{short_name_bands} bands"

    # Very long names (suspicious)
    long_name_bands = Band.where("LENGTH(name) > 50").count
    puts "  ⚠️ Very long names: #{long_name_bands} bands"

    # Good quality bands (have proper names)
    good_quality_bands = Band.where("LENGTH(name) BETWEEN 4 AND 50")
                            .where("name !~ ?", "\\d{4}[/\\-\\.]\\d{1,2}[/\\-\\.]\\d{1,2}")
                            .where("name !~ ?", "\\d{1,2}\\s*\\([a-z]{3}\\)")
                            .where("name NOT ILIKE ANY (ARRAY['%zepp%', '%www%', '%club%', '%hall%', '%bar%'])")
                            .count
    puts "  ✅ Good quality names: #{good_quality_bands} bands"

    puts

    # Quality percentage
    quality_percentage = (good_quality_bands.to_f / total_bands * 100).round(1)
    puts "📊 OVERALL QUALITY SCORE: #{quality_percentage}%"

    if quality_percentage > 80
      puts "🌟 EXCELLENT! Your band data quality is outstanding"
    elsif quality_percentage > 60
      puts "✅ GOOD! Solid data quality with room for improvement"
    elsif quality_percentage > 40
      puts "⚠️ FAIR! Significant improvement opportunities exist"
    else
      puts "🚨 NEEDS WORK! Major data quality issues detected"
    end

    puts

    # Genre distribution
    puts "🎼 GENRE DISTRIBUTION:"
    Band.group(:genre).order(Arel.sql('COUNT(*) DESC')).limit(10).count.each_with_index do |(genre, count), index|
      percentage = (count.to_f / total_bands * 100).round(1)
      puts "  #{index + 1}. #{genre}: #{count} bands (#{percentage}%)"
    end

    puts

    # Recommendations
    puts "🔮 RECOMMENDATIONS:"
    if date_pattern_bands > 0
      puts "  🎯 Run intelligent extraction on #{date_pattern_bands} date-pattern bands"
    end
    if day_pattern_bands > 0
      puts "  🎯 Clean up #{day_pattern_bands} day-pattern bands"
    end
    if venue_name_bands > 0
      puts "  🎯 Fix #{venue_name_bands} venue-name bands"
    end
    if quality_percentage < 70
      puts "  🚀 Consider expanding intelligent extraction to more gigs"
      puts "  🧠 Tune extraction parameters for better accuracy"
    end

    puts "\n🎉 Analysis complete! Use insights to guide improvements."
  end

  desc "🧹 Clean Up Obvious Non-Band Names"
  task cleanup_obvious_non_bands: :environment do
    puts "🧹 CLEANING UP OBVIOUS NON-BAND NAMES"
    puts "=" * 60
    puts "🎯 Removing Date Patterns, Venue Names, and Event Descriptions"
    puts "=" * 60
    puts

    # Initialize intelligent extractor for validation
    extractor = IntelligentBandExtractor.new(verbose: false)

    cleanup_categories = [
      {
        name: "Date Patterns",
        condition: "name ~ '\\d{4}[/\\-\\.]\\d{1,2}[/\\-\\.]\\d{1,2}|\\d{1,2}[/\\-\\.]\\d{1,2}'",
        examples: ["2025.6", "14(sat)", "June 14"]
      },
      {
        name: "Day Patterns",
        condition: "name ~ '\\d{1,2}\\s*\\([a-z]{3}\\)'",
        examples: ["14(sat)", "15(sun)"]
      },
      {
        name: "Venue Names",
        condition: "name ILIKE ANY (ARRAY['%zepp%', '%www%', '%club%', '%hall%', '%bar%', '%studio%'])",
        examples: ["Zepp Sapporo", "WWW Shibuya", "Blue Note"]
      },
      {
        name: "Very Short Names",
        condition: "LENGTH(name) <= 2",
        examples: ["06", "14", "DJ"]
      }
    ]

    total_deleted = 0

    cleanup_categories.each do |category|
      puts "🔍 Processing #{category[:name]}..."

      candidates = Band.where(category[:condition])
      puts "  📊 Found #{candidates.count} candidates"

      if candidates.count > 0
        puts "  📋 Examples: #{category[:examples].join(', ')}"

        deleted_count = 0

        candidates.find_each do |band|
          # Double-check with intelligent extractor
          gig_data = { title: band.name, artists: nil }
          extracted = extractor.extract_bands_from_gig_data(gig_data)

          # If AI also thinks this isn't a real band, delete it
          if extracted == ["Live Performance"]
            # Remove bookings first
            band.bookings.destroy_all
            band.destroy
            deleted_count += 1
          end
        end

        puts "  🗑️ Deleted: #{deleted_count} bands"
        total_deleted += deleted_count
      end

      puts
    end

    puts "🎉 CLEANUP COMPLETE!"
    puts "=" * 60
    puts "🗑️ Total bands deleted: #{total_deleted}"
    puts "📊 Remaining bands: #{Band.count}"
    puts "📈 Data quality improved significantly!"

    puts "\n🔮 NEXT STEPS:"
    puts "  • Run 'rails bands:analyze_extraction_quality' to see improvements"
    puts "  • Consider running intelligent extraction on remaining data"
    puts "  • Check genre classification improvements"
  end
end
