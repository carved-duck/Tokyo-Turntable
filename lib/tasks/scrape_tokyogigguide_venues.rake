namespace :scrape do
  desc "Scrape all venues from TokyoGigGuide to build foundational venue database"
  task :tokyogigguide_venues => :environment do
    puts "🏢 SCRAPING ALL VENUES FROM TOKYOGIGGUIDE"
    puts "=" * 60
    puts "🎯 Purpose: Get all venues with real website data from TokyoGigGuide"
    puts "📊 This will give us the foundation for future gig scraping"
    puts ""

    require 'selenium-webdriver'
    require 'nokogiri'

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920,1080')

    driver = Selenium::WebDriver.for(:chrome, options: options)

    begin
      all_venues = []
      page_num = 1

      loop do
        url = "https://www.tokyogigguide.com/en/venues?page=#{page_num}"
        puts "📄 Scraping page #{page_num}: #{url}"

        driver.get(url)
        sleep(2) # Let page load

        # Parse the page
        doc = Nokogiri::HTML(driver.page_source)
        venue_links = doc.css('a[href*="/en/venues/"]')

        if venue_links.empty?
          puts "✅ No more venues found on page #{page_num}. Stopping."
          break
        end

        venues_on_page = 0
        venue_links.each do |link|
          venue_name = link.text.strip
          venue_path = link['href']

          next if venue_name.blank? || venue_path.blank?
          next if venue_path.include?('?page=') # Skip pagination links

          venue_url = "https://www.tokyogigguide.com#{venue_path}"

          venue_data = {
            name: venue_name,
            tokyogigguide_url: venue_url,
            scraped_at: Time.current
          }

          all_venues << venue_data
          venues_on_page += 1
        end

        puts "  ✅ Found #{venues_on_page} venues on page #{page_num}"

        # Check if there's a next page
        next_link = doc.css('a[rel="next"]')
        if next_link.empty?
          puts "✅ Reached last page. Total pages: #{page_num}"
          break
        end

        page_num += 1
        sleep(1) # Be respectful
      end

      puts "\n📊 VENUE DISCOVERY COMPLETE!"
      puts "Found #{all_venues.count} venues total"

      # Now scrape individual venue pages to get real websites
      puts "\n🌐 SCRAPING INDIVIDUAL VENUE PAGES FOR REAL WEBSITES..."
      venues_with_websites = 0

      all_venues.each_with_index do |venue_data, index|
        puts "  [#{index + 1}/#{all_venues.count}] #{venue_data[:name]}"

        begin
          driver.get(venue_data[:tokyogigguide_url])
          sleep(1)

          doc = Nokogiri::HTML(driver.page_source)

          # Look for website links
          website_link = doc.css('a[href^="http"]:not([href*="tokyogigguide"]):not([href*="facebook"]):not([href*="twitter"]):not([href*="instagram"])').first

          if website_link
            real_website = website_link['href']
            venue_data[:real_website] = real_website
            venues_with_websites += 1
            puts "    ✅ Website: #{real_website}"
          else
            puts "    ❌ No real website found"
          end

          # Extract additional venue info
          address_elem = doc.css('.venue-address, .address').first
          venue_data[:address] = address_elem&.text&.strip if address_elem

          # Extract neighborhood/area
          area_elem = doc.css('.venue-area, .area').first
          venue_data[:neighborhood] = area_elem&.text&.strip if area_elem

        rescue => e
          puts "    ❌ Error scraping #{venue_data[:name]}: #{e.message}"
        end

        # Progress update
        if (index + 1) % 50 == 0
          puts "    📊 Progress: #{index + 1}/#{all_venues.count} venues processed"
        end
      end

      puts "\n💾 SAVING VENUES TO DATABASE..."

      created_venues = 0
      updated_venues = 0

      all_venues.each do |venue_data|
        # Find or create venue
        venue = Venue.find_or_initialize_by(name: venue_data[:name])

        if venue.new_record?
          venue.assign_attributes(
            address: venue_data[:address] || 'Tokyo, Japan',
            website: venue_data[:real_website],
            email: 'info@venue.com',
            neighborhood: venue_data[:neighborhood] || 'Tokyo',
            details: 'Venue information from TokyoGigGuide'
          )

          if venue.save
            created_venues += 1
          else
            puts "    ❌ Failed to save #{venue_data[:name]}: #{venue.errors.full_messages}"
          end
        else
          # Update existing venue with real website if we found one
          if venue_data[:real_website] && venue.website != venue_data[:real_website]
            venue.update(website: venue_data[:real_website])
            updated_venues += 1
          end
        end
      end

      # Save raw data to JSON for backup
      json_file = Rails.root.join('db', 'data', 'tokyogigguide_venues.json')
      File.write(json_file, JSON.pretty_generate(all_venues))

      puts "\n🎉 TOKYOGIGGUIDE VENUE SCRAPING COMPLETE!"
      puts "=" * 60
      puts "📊 Total venues found: #{all_venues.count}"
      puts "🌐 Venues with real websites: #{venues_with_websites}"
      puts "✨ New venues created: #{created_venues}"
      puts "🔄 Existing venues updated: #{updated_venues}"
      puts "💾 Raw data saved to: #{json_file}"
      puts "\n📈 Database totals:"
      puts "   Total venues: #{Venue.count}"
      puts "   Venues with websites: #{Venue.where.not(website: [nil, '']).count}"
      puts "\n🚀 Ready to run: rails scrape:ultra_fast"

    ensure
      driver.quit
    end
  end
end
