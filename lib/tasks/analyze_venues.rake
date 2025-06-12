namespace :venues do
  desc "Analyze venue website complexity and technology stack"
  task analyze_complexity: :environment do
    puts '🔍 COMPREHENSIVE VENUE ANALYSIS'
    puts '================================'

    scraper = UnifiedVenueScraper.new(verbose: true)

    # Analyze each proven venue in detail
    venues = UnifiedVenueScraper::PROVEN_VENUES
    static_venues = []
    js_venues = []
    complex_venues = []
    analysis_results = []

    venues.each do |venue_config|
      puts "\n📊 ANALYZING: #{venue_config[:name]}"
      puts "URL: #{venue_config[:url]}"

      analysis = {
        name: venue_config[:name],
        url: venue_config[:url],
        complexity: nil,
        special_handling: venue_config[:special_handling],
        http_accessible: nil,
        classification: nil,
        scraping_strategy: nil
      }

      # Test website complexity
      begin
        complexity = scraper.send(:detect_website_complexity, venue_config[:url])
        analysis[:complexity] = complexity
        puts "Complexity: #{complexity}"
      rescue => e
        puts "Complexity detection failed: #{e.message}"
        analysis[:complexity] = :unknown
      end

      # Check if it has special handling
      special = venue_config[:special_handling]
      puts "Special handling: #{special || 'none'}"

      # Test accessibility with basic HTTP
      begin
        accessible = scraper.send(:website_accessible?, venue_config[:url])
        analysis[:http_accessible] = accessible
        puts "HTTP accessible: #{accessible}"
      rescue => e
        puts "HTTP accessibility test failed: #{e.message}"
        analysis[:http_accessible] = false
      end

      # Try to determine static vs JS and recommend strategy
      if analysis[:complexity] == :static || (analysis[:complexity] == :medium && !special)
        static_venues << venue_config[:name]
        analysis[:classification] = 'Static HTML'
        analysis[:scraping_strategy] = 'HTTP + Nokogiri (fastest)'
        puts "🟢 CLASSIFICATION: Static HTML"
      elsif analysis[:complexity] == :high || special
        if special == :milkyway_date_navigation
          complex_venues << venue_config[:name]
          analysis[:classification] = 'Complex Interactive'
          analysis[:scraping_strategy] = 'Browser automation + date navigation'
          puts "🔴 CLASSIFICATION: Complex JavaScript (Interactive Calendar)"
        else
          js_venues << venue_config[:name]
          analysis[:classification] = 'JavaScript Required'
          analysis[:scraping_strategy] = 'Browser automation (standard)'
          puts "🟡 CLASSIFICATION: JavaScript Required"
        end
      else
        js_venues << venue_config[:name]
        analysis[:classification] = 'JavaScript Required'
        analysis[:scraping_strategy] = 'Browser automation (standard)'
        puts "🟡 CLASSIFICATION: JavaScript Required (default)"
      end

      analysis_results << analysis
    end

    puts "\n\n🏆 FINAL CLASSIFICATION RESULTS"
    puts "================================"
    puts "🟢 Static HTML venues (#{static_venues.count}): #{static_venues.join(', ')}"
    puts "🟡 JavaScript venues (#{js_venues.count}): #{js_venues.join(', ')}"
    puts "🔴 Complex Interactive venues (#{complex_venues.count}): #{complex_venues.join(', ')}"

    puts "\n📈 IMPROVEMENT RECOMMENDATIONS:"
    puts "==============================="
    puts "1. Static venues: Can be scraped with simple HTTP requests (3-5x faster)"
    puts "2. JavaScript venues: Need browser automation but standard scraping"
    puts "3. Complex venues: Need specialized navigation and interaction logic"

    puts "\n📋 DETAILED ANALYSIS:"
    puts "====================="
    analysis_results.each do |result|
      puts "\n#{result[:name]}:"
      puts "  • Classification: #{result[:classification]}"
      puts "  • Complexity: #{result[:complexity]}"
      puts "  • HTTP Accessible: #{result[:http_accessible]}"
      puts "  • Strategy: #{result[:scraping_strategy]}"
      puts "  • Special: #{result[:special_handling] || 'none'}"
    end

    puts "\n🚀 PERFORMANCE OPTIMIZATION OPPORTUNITIES:"
    puts "==========================================="
    if static_venues.any?
      puts "• Switch #{static_venues.count} static venues to HTTP-only scraping"
      puts "  Expected speedup: 3-5x faster per venue"
    end

    if js_venues.any?
      puts "• Optimize #{js_venues.count} JS venues with faster browser settings"
      puts "  Consider headless mode, reduced wait times"
    end

    if complex_venues.any?
      puts "• #{complex_venues.count} complex venues need specialized handling"
      puts "  May benefit from dedicated scraping strategies"
    end
  end
end
