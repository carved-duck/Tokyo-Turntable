namespace :fix do
  desc "Fix Milkyway scraping with enhanced JavaScript handling"
  task milkyway: :environment do
    puts "🥛 FIXING MILKYWAY SCRAPING"
    puts "=" * 40

    require 'selenium-webdriver'
    require 'nokogiri'

    # Create browser with JavaScript enabled
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920,1080')
    # Remove --headless to see what happens (for debugging)

    browser = Selenium::WebDriver.for(:chrome, options: options)

    begin
      puts "\n🔍 ATTEMPT 1: Extended wait on schedule page..."
      browser.get("https://www.shibuyamilkyway.com/new/SCHEDULE/")

      # Much longer wait for JavaScript to load content
      puts "  ⏳ Waiting 10 seconds for JavaScript to load..."
      sleep(10)

      html_after_wait = browser.page_source
      doc = Nokogiri::HTML(html_after_wait)
      body_text = doc.css('body').text.strip

      puts "  📄 Page length after wait: #{html_after_wait.length}"
      puts "  📝 Body text length: #{body_text.length}"

      # Look for any schedule/event content
      if body_text.include?("Jan") || body_text.include?("Feb") || body_text.include?("Mar") ||
         body_text.match?(/\d{1,2}\/\d{1,2}/) || body_text.include?("月") || body_text.include?("日")
        puts "  ✅ Found date-like content after extended wait!"

        # Try to extract any structured content
        all_text_elements = doc.css('div, span, p, td, li').map(&:text).select { |t| t.strip.length > 3 }
        date_elements = all_text_elements.select { |t|
          t.match?(/\d/) && (t.include?("月") || t.include?("日") || t.match?(/\d{1,2}\/\d{1,2}/))
        }

        puts "  🎯 Potential schedule elements found:"
        date_elements.first(5).each { |elem| puts "    - #{elem.strip}" }
      else
        puts "  ❌ Still no schedule content after extended wait"
      end

      puts "\n🔍 ATTEMPT 2: Try scrolling to trigger lazy loading..."
      browser.execute_script("window.scrollTo(0, document.body.scrollHeight);")
      sleep(3)
      browser.execute_script("window.scrollTo(0, 0);")
      sleep(3)

      html_after_scroll = browser.page_source
      if html_after_scroll != html_after_wait
        puts "  ✅ Content changed after scrolling!"
        doc_scroll = Nokogiri::HTML(html_after_scroll)
        new_body_text = doc_scroll.css('body').text.strip
        puts "  📝 New body text length: #{new_body_text.length}"
      else
        puts "  ❌ No content change after scrolling"
      end

      puts "\n🔍 ATTEMPT 3: Check for frames/iframes..."
      frames = browser.find_elements(:tag_name, 'iframe')
      if frames.any?
        puts "  🖼️ Found #{frames.count} iframe(s), checking content..."
        frames.each_with_index do |frame, index|
          begin
            browser.switch_to.frame(frame)
            frame_source = browser.page_source
            frame_text = Nokogiri::HTML(frame_source).css('body').text.strip

            if frame_text.length > 100
              puts "    Frame #{index + 1}: #{frame_text.length} chars"
              if frame_text.match?(/\d{1,2}\/\d{1,2}/) || frame_text.include?("schedule")
                puts "      ✅ This frame might contain schedule data!"
              end
            end

            browser.switch_to.default_content
          rescue => e
            puts "    Frame #{index + 1}: Error accessing - #{e.message}"
            browser.switch_to.default_content
          end
        end
      else
        puts "  📄 No iframes found"
      end

      puts "\n🔍 ATTEMPT 4: Try different URLs..."
      test_urls = [
        "https://www.shibuyamilkyway.com/schedule/",
        "https://www.shibuyamilkyway.com/events/",
        "https://www.shibuyamilkyway.com/calendar/",
        "https://www.shibuyamilkyway.com/live/",
        "https://www.shibuyamilkyway.com/new/",
        "https://www.shibuyamilkyway.com/rental/",
        "https://www.shibuyamilkyway.com"
      ]

      test_urls.each do |url|
        begin
          puts "  🔗 Testing: #{url}"
          browser.get(url)
          sleep(3)

          page_source = browser.page_source
          page_title = browser.title
          body_text = Nokogiri::HTML(page_source).css('body').text.strip

          # Look for promising content
          has_schedule = body_text.downcase.include?("schedule") ||
                        body_text.include?("予定") || body_text.include?("スケジュール")
          has_dates = body_text.match?(/\d{1,2}\/\d{1,2}/) ||
                     body_text.include?("月") && body_text.include?("日")
          has_live = body_text.downcase.include?("live") ||
                    body_text.include?("ライブ")

          score = [has_schedule, has_dates, has_live].count(true)

          puts "    📊 Score: #{score}/3 (schedule: #{has_schedule}, dates: #{has_dates}, live: #{has_live})"
          puts "    📝 Title: #{page_title}"
          puts "    📄 Length: #{body_text.length} chars"

          if score >= 2
            puts "    ✅ This URL looks promising!"

            # Try to find actual schedule elements
            doc = Nokogiri::HTML(page_source)
            potential_gigs = doc.css('div, span, p, td, li').select { |elem|
              text = elem.text.strip
              text.length > 10 && text.length < 200 &&
              (text.match?(/\d{1,2}\/\d{1,2}/) || (text.include?("月") && text.include?("日")))
            }

            if potential_gigs.any?
              puts "    🎯 Found #{potential_gigs.count} potential gig elements:"
              potential_gigs.first(3).each do |gig|
                puts "      - #{gig.text.strip.first(80)}"
              end
            end
          end

        rescue => e
          puts "    ❌ Error with #{url}: #{e.message}"
        end
      end

    rescue => e
      puts "❌ ERROR: #{e.message}"
    ensure
      browser.quit
    end

    puts "\n✅ Milkyway investigation complete!"
    puts "\n💡 RECOMMENDATIONS:"
    puts "  1. Use the most promising URL found above"
    puts "  2. Increase JavaScript wait time to 10+ seconds"
    puts "  3. Update selectors based on actual content structure"
    puts "  4. Consider if site requires user interaction to load schedule"
  end
end
