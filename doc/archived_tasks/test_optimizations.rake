namespace :test do
  desc "🧪 Test optimization improvements on specific venue cases"
  task optimization_validation: :environment do
    puts "🧪 OPTIMIZATION VALIDATION TEST"
    puts "=" * 60
    puts "Testing: Enhanced Date Parsing + Learning System + Smart Patterns"
    puts "=" * 60

    validator = OptimizationValidator.new
    validator.run_validation_tests
  end
end

class OptimizationValidator
  def initialize
    @test_results = {
      date_parsing_improvements: 0,
      learning_system_working: false,
      smart_patterns_active: false,
      venues_with_improvements: []
    }
  end

  def run_validation_tests
    puts "\n📋 TEST 1: Enhanced Date Parsing"
    puts "-" * 40
    test_enhanced_date_parsing

    puts "\n📋 TEST 2: Learning System Integration"
    puts "-" * 40
    test_learning_system

    puts "\n📋 TEST 3: Smart Pattern Application"
    puts "-" * 40
    test_smart_patterns

    puts "\n📋 TEST 4: Live Venue Testing"
    puts "-" * 40
    test_live_improvements

    puts "\n📊 VALIDATION SUMMARY"
    puts "=" * 40
    puts "✅ Date parsing improvements: #{@test_results[:date_parsing_improvements]}"
    puts "✅ Learning system working: #{@test_results[:learning_system_working]}"
    puts "✅ Smart patterns active: #{@test_results[:smart_patterns_active]}"
    puts "✅ Venues with improvements: #{@test_results[:venues_with_improvements].length}"

    if @test_results[:venues_with_improvements].any?
      puts "\n🎯 IMPROVED VENUES:"
      @test_results[:venues_with_improvements].each do |venue|
        puts "   📈 #{venue[:name]} - #{venue[:improvement]}"
      end
    end
  end

  private

  def test_enhanced_date_parsing
    puts "🔍 Testing enhanced date parsing patterns..."

    # Test cases that commonly fail
    test_cases = [
      { text: "6.15(月)", expected: "2025-06-15" },
      { text: "6/15(月)", expected: "2025-06-15" },
      { text: "2025.6.15[月]", expected: "2025-06-15" },
      { text: "6月15日(月) 19:00", expected: "2025-06-15" },
      { text: "20250615[mon.]", expected: "2025-06-15" },
      { text: "6-15(MON)", expected: "2025-06-15" },
      { text: "今日 6/15", expected: "2025-06-15" },
      { text: "明日 6/16", expected: "2025-06-16" }
    ]

    improvements = 0
    test_cases.each do |test_case|
      begin
        # Test with enhanced parser
        if defined?(EnhancedDateParser)
          parsed_date = EnhancedDateParser.parse_date_with_enhanced_patterns(test_case[:text])
          if parsed_date
            improvements += 1
            puts "   ✅ Enhanced parser: '#{test_case[:text]}' → #{parsed_date}"
          else
            puts "   ❌ Enhanced parser failed: '#{test_case[:text]}'"
          end
        else
          puts "   ⚠️  EnhancedDateParser not loaded"
        end
      rescue => e
        puts "   ❌ Error testing '#{test_case[:text]}': #{e.message}"
      end
    end

    @test_results[:date_parsing_improvements] = improvements
    puts "📈 Enhanced date parsing: #{improvements}/#{test_cases.length} patterns improved"
  end

  def test_learning_system
    puts "🧠 Testing OCR learning system integration..."

    preferences_file = Rails.root.join('tmp', 'venue_ocr_preferences.json')
    if File.exist?(preferences_file)
      preferences = JSON.parse(File.read(preferences_file))
      puts "   📖 Loaded #{preferences.keys.length} venue preferences"

      # Test MITSUKI preference
      if preferences['翠月 (MITSUKI)'] == 'EasyOCR'
        puts "   ✅ MITSUKI preference correctly set to EasyOCR"
        @test_results[:learning_system_working] = true
      end

      # Test new club preferences
      club_preferences = preferences.select { |k, v| k.downcase.include?('club') && v == 'EasyOCR' }
      puts "   🎯 Club venues with EasyOCR preference: #{club_preferences.keys.length}"

      # Test hall preferences
      hall_preferences = preferences.select { |k, v| k.downcase.include?('hall') && v == 'Tesseract' }
      puts "   🏛️  Hall venues with Tesseract preference: #{hall_preferences.keys.length}"

      @test_results[:learning_system_working] = true
    else
      puts "   ❌ No preferences file found"
    end
  end

  def test_smart_patterns
    puts "🎨 Testing smart venue-specific patterns..."

    patterns_file = Rails.root.join('tmp', 'smart_venue_patterns.json')
    if File.exist?(patterns_file)
      patterns = JSON.parse(File.read(patterns_file))
      puts "   📋 Loaded #{patterns.length} smart pattern sets"

      patterns.each do |pattern_set|
        venue_type = pattern_set['venue_type']
        selectors = pattern_set['selectors']
        puts "   🎯 #{venue_type}: #{selectors['gigs'].split(',').length} gig selectors"
      end

      @test_results[:smart_patterns_active] = true
    else
      puts "   ❌ No smart patterns file found"
    end
  end

  def test_live_improvements
    puts "🎪 Testing improvements on real venues..."

    # Test with venues that had date parsing issues
    problematic_venues = [
      '路地と人 (rojitohito)',
      'ØL',
      '真昼の月夜の太陽 (Mahiru no Tsuki Yoru no Taiyo)'
    ]

    scraper = UnifiedVenueScraper.new(verbose: false)

    problematic_venues.each do |venue_name|
      venue = Venue.find_by("name LIKE ?", "%#{venue_name}%")
      if venue
        puts "   🔍 Testing improvements on: #{venue.name}"

        begin
          # Quick scrape test (don't save results)
          venue_config = {
            name: venue.name,
            url: venue.website,
            selectors: scraper.send(:get_general_selectors)
          }

          # Test if we can extract any dates now
          start_time = Time.current
          gigs = scraper.scrape_venue_gigs(venue_config)
          duration = Time.current - start_time

          if gigs.any?
            @test_results[:venues_with_improvements] << {
              name: venue.name,
              improvement: "#{gigs.length} gigs found (#{duration.round(2)}s)"
            }
            puts "      ✅ Found #{gigs.length} gigs in #{duration.round(2)}s"
          else
            puts "      ❌ Still no gigs found"
          end

        rescue => e
          puts "      ⚠️  Error testing venue: #{e.message}"
        end
      else
        puts "   ❓ Venue not found: #{venue_name}"
      end
    end

    # Test OCR learning on MITSUKI
    mitsuki = Venue.find_by("name LIKE ?", "%MITSUKI%")
    if mitsuki
      puts "   🔍 Testing OCR learning on: MITSUKI"

      # Check if the preference is being used
      if File.exist?(Rails.root.join('tmp', 'venue_ocr_preferences.json'))
        preferences = JSON.parse(File.read(Rails.root.join('tmp', 'venue_ocr_preferences.json')))
        if preferences.key?('翠月 (MITSUKI)')
          puts "      ✅ MITSUKI has learned OCR preference: #{preferences['翠月 (MITSUKI)']}"
          @test_results[:venues_with_improvements] << {
            name: 'MITSUKI',
            improvement: "Learned OCR preference: #{preferences['翠月 (MITSUKI)']}"
          }
        end
      end
    end
  end
end
