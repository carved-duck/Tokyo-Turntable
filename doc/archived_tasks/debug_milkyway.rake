namespace :debug do
  desc "Debug Milkyway specifically to see what's changed"
  task milkyway: :environment do
    puts "🥛 MILKYWAY DEBUGGING SESSION"
    puts "=" * 50

    require 'selenium-webdriver'
    require 'nokogiri'

    milkyway_config = {
      name: "Milkyway",
      url: "https://www.shibuyamilkyway.com",
      urls: ["https://www.shibuyamilkyway.com", "https://www.shibuyamilkyway.com/new/SCHEDULE/"],
      special_handling: :milkyway_date_navigation,
      selectors: {
        gigs: '.gig, .schedule-item, article, .post, div[class*="schedule"], div[class*="event"], div, span, table tr',
        title: 'span, h1, h2, h3, .title, .gig-title, div[class*="title"]',
        date: 'span, .date, .gig-date, time, .meta, div[class*="date"]',
        time: 'span, .time, .start-time, .gig-time, div[class*="time"]',
        artists: 'span, .artist, .performer, .lineup, .act, div[class*="artist"]'
      }
    }

    # Create browser
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920,1080')

    browser = Selenium::WebDriver.for(:chrome, options: options)

    begin
      puts "\n🔍 STEP 1: Testing main page..."
      browser.get(milkyway_config[:url])
      sleep(3)

      main_html = browser.page_source
      puts "  📄 Page source length: #{main_html.length}"
      puts "  📝 Page title: #{browser.title}"

      # Check if page loaded properly
      if main_html.include?("milkyway") || main_html.include?("MILKYWAY") || main_html.include?("schedule")
        puts "  ✅ Page seems to contain Milkyway content"
      else
        puts "  ❌ Page doesn't seem to contain expected content"
      end

      puts "\n🔍 STEP 2: Testing schedule page..."
      browser.get("#{milkyway_config[:url]}/new/SCHEDULE/")
      sleep(3)

      schedule_html = browser.page_source
      puts "  📄 Schedule page source length: #{schedule_html.length}"
      puts "  📝 Schedule page title: #{browser.title}"

      # Look for specific content
      content_indicators = [
        "schedule", "Schedule", "SCHEDULE",
        "event", "Event", "EVENT",
        "live", "Live", "LIVE",
        "2025", "202", "Jan", "Feb", "Mar",
        "月", "日", "曜"  # Japanese date characters
      ]

      found_indicators = content_indicators.select { |indicator| schedule_html.include?(indicator) }
      puts "  🔍 Found content indicators: #{found_indicators.join(', ')}" if found_indicators.any?
      puts "  ❌ No recognizable content indicators found" if found_indicators.empty?

      puts "\n🔍 STEP 3: Analyzing page structure..."
      doc = Nokogiri::HTML(schedule_html)

      # Check for common elements
      structure_info = {
        total_divs: doc.css('div').count,
        total_spans: doc.css('span').count,
        total_links: doc.css('a').count,
        total_tables: doc.css('table').count,
        total_scripts: doc.css('script').count,
        body_text_length: doc.css('body').text.strip.length
      }

      puts "  📊 Page structure:"
      structure_info.each { |key, value| puts "    #{key}: #{value}" }

      puts "\n🔍 STEP 4: Looking for potential gig elements..."

      # Try each selector from our config
      milkyway_config[:selectors][:gigs].split(', ').each do |selector|
        begin
          elements = doc.css(selector.strip)
          if elements.any?
            puts "  ✅ Selector '#{selector}' found #{elements.count} elements"

            # Sample first few elements
            elements.first(3).each_with_index do |element, index|
              text = element.text.strip
              next if text.empty?
              puts "    Sample #{index + 1}: #{text.first(100)}#{text.length > 100 ? '...' : ''}"
            end
          else
            puts "  ❌ Selector '#{selector}' found 0 elements"
          end
        rescue => e
          puts "  ⚠️ Selector '#{selector}' failed: #{e.message}"
        end
      end

      puts "\n🔍 STEP 5: Looking for date patterns in page text..."
      body_text = doc.css('body').text

      # Look for date patterns
      date_patterns = [
        /\d{4}[-\/]\d{1,2}[-\/]\d{1,2}/,  # 2025-01-15 or 2025/01/15
        /\d{1,2}[-\/]\d{1,2}[-\/]\d{4}/,  # 15-01-2025 or 15/01/2025
        /\d{1,2}月\d{1,2}日/,             # 1月15日 (Japanese)
        /Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec/i,
        /January|February|March|April|May|June|July|August|September|October|November|December/i
      ]

      date_matches = []
      date_patterns.each do |pattern|
        matches = body_text.scan(pattern)
        date_matches.concat(matches) if matches.any?
      end

      if date_matches.any?
        puts "  ✅ Found #{date_matches.count} potential dates:"
        date_matches.uniq.first(5).each { |match| puts "    - #{match}" }
      else
        puts "  ❌ No date patterns found in page text"
      end

      puts "\n🔍 STEP 6: Checking for JavaScript/dynamic content..."

      # Check for common JS frameworks/indicators
      js_indicators = [
        "turbo", "Turbo", "TURBO",
        "react", "React", "REACT",
        "vue", "Vue", "VUE",
        "angular", "Angular", "ANGULAR",
        "stimulus", "Stimulus", "STIMULUS",
        "rails", "Rails", "RAILS"
      ]

      found_js = js_indicators.select { |indicator| schedule_html.include?(indicator) }
      puts "  🔍 JS framework indicators: #{found_js.join(', ')}" if found_js.any?
      puts "  📄 Static HTML (no JS indicators)" if found_js.empty?

      # Look for form elements or interactive components
      interactive_elements = {
        buttons: doc.css('button').count,
        forms: doc.css('form').count,
        inputs: doc.css('input').count,
        selects: doc.css('select').count
      }

      puts "  🎛️ Interactive elements:"
      interactive_elements.each { |key, value| puts "    #{key}: #{value}" }

      puts "\n🔍 STEP 7: Sample raw HTML snippet..."
      body_html = doc.css('body').inner_html
      if body_html.length > 500
        puts "  📝 Body HTML sample (first 500 chars):"
        puts "    #{body_html.first(500)}..."
      else
        puts "  📝 Full body HTML:"
        puts "    #{body_html}"
      end

    rescue => e
      puts "❌ ERROR during debugging: #{e.message}"
      puts "  #{e.backtrace.first(3).join("\n  ")}"
    ensure
      browser.quit
    end

    puts "\n✅ Milkyway debugging complete!"
    puts "\n💡 NEXT STEPS:"
    puts "  1. Check if website structure changed"
    puts "  2. Update selectors if needed"
    puts "  3. Handle any new JavaScript requirements"
    puts "  4. Test with updated configuration"
  end
end
