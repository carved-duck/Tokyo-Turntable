namespace :scrape do
  desc "Scrape all venues and gigs from TokyoGigGuide - The Complete Solution"
  task :tokyogigguide => :environment do
    puts "🎵 SCRAPING ALL DATA FROM TOKYOGIGGUIDE"
    puts "=" * 60
    puts "🎯 Step 1: Get all venues from https://www.tokyogigguide.com/en/livehouses"
    puts "🎯 Step 2: Scrape each venue's gigs and events"
    puts "📊 This will give us the complete TokyoGigGuide database"
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

      # Step 1: Scrape all venues from the livehouses page
      puts "📄 STEP 1: SCRAPING VENUES FROM LIVEHOUSES PAGE"
      puts "🌐 URL: https://www.tokyogigguide.com/en/livehouses"

      page_num = 1

      loop do
        url = "https://www.tokyogigguide.com/en/livehouses?limitstart=#{(page_num - 1) * 50}"
        puts "  📄 Scraping page #{page_num}: #{url}"

        driver.get(url)
        sleep(3) # Let page load completely

        # Parse the page
        doc = Nokogiri::HTML(driver.page_source)

        # Look for venue entries - they appear to be in a list format
        venue_elements = doc.css('table tr, .venue-entry, li').select do |elem|
          text = elem.text.strip
          # Look for elements that contain venue names and areas
          text.length > 3 && text.length < 200 &&
          (text.match?(/\w+/) && !text.match?(/^(Search|Clear|Live House|Area|\d+|»|End|Powered by)$/))
        end

        venues_found_on_page = 0

        venue_elements.each do |elem|
          # Extract venue name and area
          text = elem.text.strip
          next if text.blank?

          # Skip navigation and header elements
          next if text.match?(/^(Search|Clear|Live House|Area|\d+|»|End|Powered by|FaLang|©|Site Credits|Contact|Home|GIGS|ALL GIGS)/)

          # Look for venue links
          venue_link = elem.css('a').first
          next unless venue_link

          venue_href = venue_link['href']
          next unless venue_href&.include?('/venue/')

          venue_name = venue_link.text.strip
          next if venue_name.blank?

          # Extract area information
          area = ""
          if text.include?(venue_name)
            remaining_text = text.gsub(venue_name, '').strip
            area = remaining_text unless remaining_text.blank?
          end

          venue_url = venue_href.start_with?('http') ? venue_href : "https://www.tokyogigguide.com#{venue_href}"

          venue_data = {
            name: venue_name,
            area: area,
            tokyogigguide_url: venue_url,
            scraped_at: Time.current
          }

          all_venues << venue_data
          venues_found_on_page += 1

          puts "    ✅ #{venue_name} (#{area})"
        end

        puts "  📊 Found #{venues_found_on_page} venues on page #{page_num}"

        # Check if there are more pages
        next_link = doc.css('a').find { |a| a.text.strip == '»' || a.text.strip.match?(/next/i) }
        if next_link.nil? || venues_found_on_page == 0
          puts "✅ Reached last page. Total pages: #{page_num}"
          break
        end

        page_num += 1
        sleep(2) # Be respectful
        break if page_num > 20 # Safety limit
      end

      puts "\n📊 VENUE DISCOVERY COMPLETE!"
      puts "Found #{all_venues.count} venues total"

      # Step 2: Scrape individual venue pages for gigs and details
      puts "\n🎵 STEP 2: SCRAPING GIGS FROM EACH VENUE..."

      created_venues = 0
      updated_venues = 0
      total_gigs = 0

      all_venues.each_with_index do |venue_data, index|
        puts "\n[#{index + 1}/#{all_venues.count}] 🏢 #{venue_data[:name]}"

        begin
          # Get venue page
          driver.get(venue_data[:tokyogigguide_url])
          sleep(2)

          doc = Nokogiri::HTML(driver.page_source)

          # Extract venue details
          # Look for website links
          website_links = doc.css('a[href^="http"]').reject do |link|
            href = link['href']
            href.include?('tokyogigguide') || href.include?('facebook') ||
            href.include?('twitter') || href.include?('instagram') ||
            href.include?('youtube') || href.include?('mailto')
          end

          real_website = website_links.first&.[]('href')

          # Extract address/location info
          address_text = doc.css('.venue-details, .location, .address').first&.text&.strip

          # Create or update venue in database
          venue = Venue.find_or_initialize_by(name: venue_data[:name])

          if venue.new_record?
            venue.assign_attributes(
              address: address_text || "#{venue_data[:area]}, Tokyo, Japan",
              website: real_website,
              email: 'info@venue.com',
              neighborhood: venue_data[:area] || 'Tokyo',
              details: 'Venue information from TokyoGigGuide'
            )

            if venue.save
              created_venues += 1
              puts "  ✨ Created venue: #{venue.name}"
            else
              puts "  ❌ Failed to save venue: #{venue.errors.full_messages}"
              next
            end
          else
            # Update with real website if found
            if real_website && venue.website != real_website
              venue.update(website: real_website)
              updated_venues += 1
              puts "  🔄 Updated website: #{real_website}"
            end
          end

          # Extract gigs from this venue page
          gig_elements = doc.css('.event, .gig, .listing, tr').select do |elem|
            text = elem.text
            # Look for date patterns and event indicators
            text.match?(/\d{4}[-\/]\d{1,2}[-\/]\d{1,2}|\d{1,2}[-\/]\d{1,2}[-\/]\d{4}/) ||
            text.match?(/jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec/i) ||
            text.match?(/\d{1,2}:\d{2}/) # Time patterns
          end

          gigs_found = 0

          gig_elements.each do |gig_elem|
            gig_text = gig_elem.text.strip
            next if gig_text.length < 10

            # Extract date
            date_match = gig_text.match(/(\d{4}[-\/]\d{1,2}[-\/]\d{1,2}|\d{1,2}[-\/]\d{1,2}[-\/]\d{4})/)
            next unless date_match

            begin
              gig_date = Date.parse(date_match[1])
              next if gig_date < Date.current # Skip past events
            rescue
              next
            end

            # Extract bands/artists
            bands = []
            # Look for band links or text after removing date and venue info
            band_links = gig_elem.css('a').reject { |a| a['href']&.include?('/venue/') }

            if band_links.any?
              bands = band_links.map { |link| link.text.strip }.reject(&:blank?)
            else
              # Try to extract band names from text
              clean_text = gig_text.gsub(date_match[0], '').gsub(venue.name, '').strip
              # Split by common separators
              potential_bands = clean_text.split(/[,&+\n\r]/).map(&:strip).reject(&:blank?)
              bands = potential_bands.first(3) # Take first 3 as bands
            end

            next if bands.empty?

            # Extract times
            open_time = gig_text.match(/open[:\s]*(\d{1,2}:\d{2})/i)&.[](1)
            start_time = gig_text.match(/start[:\s]*(\d{1,2}:\d{2})/i)&.[](1)

            # Extract price
            price_match = gig_text.match(/¥[\d,]+|\d+\s*yen/i)
            price = price_match ? price_match[0].gsub(/[¥,yen\s]/i, '').to_i : 0

            # Check if gig already exists
            existing_gig = Gig.find_by(date: gig_date, venue: venue)
            next if existing_gig

            # Create gig
            gig = Gig.new(
              date: gig_date,
              venue: venue,
              user: User.first || User.create!(email: 'admin@tokyogigguide.com', password: 'password'),
              open_time: open_time,
              start_time: start_time,
              price: price
            )

            if gig.save
              gigs_found += 1
              total_gigs += 1

              # Create bands
              bands.each do |band_name|
                next if band_name.length < 2

                band = Band.find_or_create_by(name: band_name) do |b|
                  b.hometown = 'Tokyo, Japan'
                  b.email = 'contact@band.com'
                  b.genre = 'Rock'
                end

                # Create booking (gig-band relationship)
                Booking.find_or_create_by(gig: gig, band: band)
              end
            end
          end

          puts "  🎵 Found #{gigs_found} gigs"

        rescue => e
          puts "  ❌ Error scraping #{venue_data[:name]}: #{e.message}"
        end

        # Progress update every 25 venues
        if (index + 1) % 25 == 0
          puts "\n📊 Progress: #{index + 1}/#{all_venues.count} venues processed"
          puts "📈 So far: #{total_gigs} gigs created"
        end
      end

      # Save venue data as backup
      json_file = Rails.root.join('db', 'data', 'tokyogigguide_complete.json')
      File.write(json_file, JSON.pretty_generate({
        venues: all_venues,
        scraped_at: Time.current,
        stats: {
          total_venues: all_venues.count,
          created_venues: created_venues,
          updated_venues: updated_venues,
          total_gigs: total_gigs
        }
      }))

      puts "\n🎉 TOKYOGIGGUIDE SCRAPING COMPLETE!"
      puts "=" * 60
      puts "📊 Venues found: #{all_venues.count}"
      puts "✨ New venues created: #{created_venues}"
      puts "🔄 Existing venues updated: #{updated_venues}"
      puts "🎵 Total gigs created: #{total_gigs}"
      puts "💾 Data saved to: #{json_file}"
      puts "\n📈 Final database totals:"
      puts "   Total venues: #{Venue.count}"
      puts "   Total gigs: #{Gig.count}"
      puts "   Total bands: #{Band.count}"
      puts "\n🚀 Your TokyoGigGuide database is now complete!"

    ensure
      driver.quit
    end
  end
end
