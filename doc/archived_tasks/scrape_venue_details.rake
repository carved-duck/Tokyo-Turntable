namespace :scrape do
  desc "Scrape COMPLETE venue details from TokyoGigGuide using proper selectors"
  task :venue_details => :environment do
    puts "🏢 SCRAPING COMPLETE VENUE DETAILS FROM TOKYOGIGGUIDE"
    puts "=" * 60
    puts "🎯 Purpose: Get ALL venue data - address, website, area, images, Japanese address"
    puts "📋 Fields: name, address, website, email, neighborhood, details, photo"
    puts "📊 Current venues: #{Venue.count}"
    puts ""

    require 'selenium-webdriver'
    require 'nokogiri'
    require 'open-uri'

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920,1080')

    driver = Selenium::WebDriver.for(:chrome, options: options)

    begin
      # Step 1: Get all venue URLs from our existing database with TokyoGigGuide URLs
      venues_with_tgg_urls = Venue.where("website LIKE '%tokyogigguide%'")

      puts "🔍 STEP 1: PROCESSING VENUES WITH TOKYOGIGGUIDE URLS"
      puts "Found #{venues_with_tgg_urls.count} venues with TokyoGigGuide URLs"

      if venues_with_tgg_urls.empty?
        puts "❌ No venues with TokyoGigGuide URLs found. Need to populate venues first."
        exit 1
      end

      updated_venues = 0
      venues_with_photos = 0
      total_fields_updated = 0

      venues_with_tgg_urls.each_with_index do |venue, index|
        venue_url = venue.website
        puts "\n[#{index + 1}/#{venues_with_tgg_urls.count}] 🏢 #{venue.name}"
        puts "  🌐 URL: #{venue_url}"

        begin
          driver.get(venue_url)
          sleep(3) # Let page load completely

          doc = Nokogiri::HTML(driver.page_source)
          venue_updates = {}

          # Extract venue data using the actual TokyoGigGuide structure

          # 1. Website (real venue website, not TokyoGigGuide)
          website_elem = doc.css('dd.venue a[href^="http"]:not([href*="tokyogigguide"])')
          if website_elem.any?
            real_website = website_elem.first['href']
            venue_updates[:website] = real_website
            puts "  🌐 Real Website: #{real_website}"
          end

          # 2. Address (English)
          address_elem = doc.css('dd.venue_street[itemprop="streetAddress"]')
          if address_elem.any?
            address = address_elem.text.strip
            if address.present? && address != venue.address
              venue_updates[:address] = address
              puts "  📍 Address: #{address}"
            end
          end

          # 3. Area/Neighborhood
          area_elem = doc.css('dd.venue_city[itemprop="addressLocality"]')
          if area_elem.any?
            area = area_elem.text.strip
            if area.present? && area != venue.neighborhood
              venue_updates[:neighborhood] = area
              puts "  🗺️ Area: #{area}"
            end
          end

          # 4. Japanese Address (for details field)
          japanese_address_elem = doc.css('dd.custom1')
          japanese_address = japanese_address_elem.text.strip if japanese_address_elem.any?

          # 5. Map link and closest stations
          map_link_elem = doc.css('dd.custom2 a')
          map_link = map_link_elem.first['href'] if map_link_elem.any?

          stations_elem = doc.css('dd.custom3')
          stations = stations_elem.text.strip if stations_elem.any?

          # 6. Build comprehensive details
          details_parts = []
          details_parts << "Live house in #{area}" if area.present?
          details_parts << "Address: #{venue_updates[:address] || venue.address}" if venue_updates[:address] || venue.address != "Tokyo, Japan"
          details_parts << "Japanese: #{japanese_address}" if japanese_address.present?
          details_parts << "Nearest station: #{stations}" if stations.present?
          details_parts << "Map: #{map_link}" if map_link.present?

          if details_parts.any?
            venue_details = details_parts.join(" | ")
            venue_updates[:details] = venue_details
            puts "  📝 Details: #{venue_details[0..100]}..."
          end

          # 7. Venue Image
          image_elem = doc.css('div.flyerimage a.flyermodal img, div.jem-img img')
          if image_elem.any?
            image_url = image_elem.first['src']

            # Convert relative URLs to absolute
            if image_url&.start_with?('/')
              image_url = "https://www.tokyogigguide.com#{image_url}"
            end

            if image_url&.start_with?('http') && !venue.photo.attached?
              begin
                puts "  📷 Downloading image: #{image_url}"

                # Download and attach the image
                image_data = URI.open(image_url)
                filename = File.basename(image_url).split('?').first
                filename = "#{venue.name.downcase.gsub(/[^a-z0-9]/, '_')}.jpg" if filename.blank?

                venue.photo.attach(
                  io: image_data,
                  filename: filename,
                  content_type: 'image/jpeg'
                )

                venues_with_photos += 1
                puts "  ✅ Photo attached successfully"

              rescue => photo_error
                puts "  ⚠️ Failed to download photo: #{photo_error.message}"
              end
            end
          end

          # 8. Extract contact email from venue's real website if available
          if venue_updates[:website]
            begin
              puts "  📧 Checking real website for contact info..."
              driver.get(venue_updates[:website])
              sleep(2)

              website_doc = Nokogiri::HTML(driver.page_source)
              email_links = website_doc.css('a[href^="mailto:"]')

              if email_links.any?
                email = email_links.first['href'].gsub('mailto:', '')
                if email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
                  venue_updates[:email] = email
                  puts "  📧 Email: #{email}"
                end
              end
            rescue => email_error
              puts "  ⚠️ Could not check real website: #{email_error.message}"
            end
          end

          # Update venue if we found new information
          if venue_updates.any?
            venue.update!(venue_updates)
            updated_venues += 1
            total_fields_updated += venue_updates.keys.count
            puts "  ✅ Updated #{venue_updates.keys.count} fields: #{venue_updates.keys.join(', ')}"
          else
            puts "  ℹ️ No new information found"
          end

        rescue => e
          puts "  ❌ Error: #{e.message}"
        end

        # Progress update every 20 venues
        if (index + 1) % 20 == 0
          puts "\n📊 Progress: #{index + 1}/#{venues_with_tgg_urls.count} venues processed"
          puts "✅ Updated: #{updated_venues} venues"
          puts "📷 Photos added: #{venues_with_photos}"
        end

        sleep(2) # Be respectful to TokyoGigGuide
      end

      # Step 2: Process venues that need TokyoGigGuide URLs
      puts "\n🔍 STEP 2: FINDING TOKYOGIGGUIDE URLS FOR REMAINING VENUES"

      venues_without_tgg = Venue.where("website IS NULL OR website NOT LIKE '%tokyogigguide%'").limit(100)
      puts "Found #{venues_without_tgg.count} venues that might need TokyoGigGuide URLs"

      if venues_without_tgg.any?
        # Get venue list from TokyoGigGuide livehouses page
        driver.get("https://www.tokyogigguide.com/en/livehouses")
        sleep(3)

        doc = Nokogiri::HTML(driver.page_source)
        tgg_venue_links = {}

        # Extract all venue links from the page
        doc.css('a[href*="/venue/"]').each do |link|
          venue_name = link.text.strip
          venue_href = link['href']
          next if venue_name.blank?

          venue_url = venue_href.start_with?('http') ? venue_href : "https://www.tokyogigguide.com#{venue_href}"
          tgg_venue_links[venue_name.downcase] = venue_url
        end

        puts "Found #{tgg_venue_links.count} venue links on TokyoGigGuide"

        # Match venues with TokyoGigGuide URLs
        matched_venues = 0
        venues_without_tgg.each do |venue|
          venue_key = venue.name.downcase

          # Try exact match first
          tgg_url = tgg_venue_links[venue_key]

          # Try fuzzy matching
          unless tgg_url
            tgg_venue_links.each do |tgg_name, url|
              if tgg_name.include?(venue_key) || venue_key.include?(tgg_name)
                tgg_url = url
                break
              end
            end
          end

          if tgg_url
            venue.update!(website: tgg_url)
            matched_venues += 1
            puts "  ✅ Matched #{venue.name} → #{tgg_url}"
          end
        end

        puts "📊 Matched #{matched_venues} additional venues with TokyoGigGuide URLs"
      end

      puts "\n🎉 VENUE DETAILS SCRAPING COMPLETE!"
      puts "=" * 60
      puts "📊 Total venues processed: #{venues_with_tgg_urls.count}"
      puts "✅ Venues updated: #{updated_venues}"
      puts "📷 Photos added: #{venues_with_photos}"
      puts "🔧 Total fields updated: #{total_fields_updated}"

      # Final validation
      puts "\n🔍 VALIDATION SUMMARY:"
      venues_with_real_websites = Venue.where.not(website: [nil, '']).where('website NOT LIKE ?', '%tokyogigguide%').count
      venues_with_photos = Venue.joins(:photo_attachment).count
      venues_with_proper_addresses = Venue.where.not(address: ['Tokyo, Japan', nil, '']).count
      venues_with_details = Venue.where.not(details: [nil, '', 'Venue information from TokyoGigGuide']).count

      puts "🌐 Venues with real websites: #{venues_with_real_websites}"
      puts "📷 Venues with photos: #{venues_with_photos}"
      puts "📍 Venues with proper addresses: #{venues_with_proper_addresses}"
      puts "📝 Venues with detailed info: #{venues_with_details}"

      puts "\n🚀 Database is ready for gig scraping!"

    ensure
      driver.quit
    end
  end
end
