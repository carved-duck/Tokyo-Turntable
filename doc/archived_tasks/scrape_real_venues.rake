namespace :scrape do
  desc "Scrape venues with real websites (not TokyoGigGuide URLs)"
  task real_venues: :environment do
    puts '🎯 SCRAPING VENUES WITH REAL WEBSITES'
    puts '===================================='

    # Get venues with real websites (not TokyoGigGuide URLs)
    venues = Venue.where.not(website: [nil, ''])
                  .where('website NOT LIKE ?', '%tokyogigguide%')
                  .order(:name)

    puts "📊 Found #{venues.count} venues with real websites:"
    venues.each { |v| puts "  - #{v.name}: #{v.website}" }

    # Initialize the scraper
    scraper = UnifiedVenueScraper.new(verbose: true)

    total_gigs = 0
    successful_venues = 0
    failed_venues = []

    venues.each_with_index do |venue, index|
      puts "\n🎯 [#{index + 1}/#{venues.count}] Scraping: #{venue.name}"
      puts "🌐 URL: #{venue.website}"

      begin
        # Create venue config for the scraper
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }

        # Scrape the venue
        gigs = scraper.send(:scrape_venue_optimized, venue_config)

        if gigs && gigs.any?
          # Filter valid gigs
          valid_gigs = gigs.select do |gig|
            gig[:date] && gig[:title] &&
            gig[:date] != 'Invalid Date' &&
            gig[:title].length > 3
          end

          if valid_gigs.any?
            puts "✅ Found #{valid_gigs.count} valid gigs"

            # Save to database
            saved_count = 0
            valid_gigs.each do |gig_data|
              begin
                # Find or create the venue
                venue_record = Venue.find_by(name: gig_data[:venue]) || venue

                # Parse time from the gig data
                parsed_time = gig_data[:time] || '19:00'
                # Extract just the time part if it contains date info
                if parsed_time.match(/(\d{1,2}):(\d{2})/)
                  start_time = $&  # The matched time
                else
                  start_time = '19:00'  # Default
                end

                # Create or find bands from title and artists
                band_names = []
                if gig_data[:artists] && gig_data[:artists].length > 3
                  band_names = gig_data[:artists].split(/[,\/&]/).map(&:strip)
                elsif gig_data[:title] && gig_data[:title].length > 3
                  # Use title as band name if no artists specified
                  band_names = [gig_data[:title]]
                else
                  band_names = ['Unknown Artist']
                end

                bands = band_names.map do |band_name|
                  Band.find_or_create_by(name: band_name.strip) do |band|
                    band.genre = 'Unknown'  # Will be properly classified by scraper
                    band.hometown = 'Tokyo, Japan'  # Default hometown
                    band.email = 'contact@band.com'  # Default email
                  end
                end

                # Create the gig (without title field)
                gig = Gig.find_or_create_by(
                  date: Date.parse(gig_data[:date]),
                  venue: venue_record,
                  start_time: start_time
                ) do |g|
                  g.open_time = start_time  # Use same time for open_time
                  g.price = gig_data[:price] || 'TBD'
                  g.user = User.first  # Assign to first user or create a default one
                end

                # Associate bands with the gig
                bands.each { |band| gig.bands << band unless gig.bands.include?(band) }

                saved_count += 1
              rescue => e
                puts "    ⚠️ Error saving gig: #{e.message}"
              end
            end

            puts "    💾 Saved #{saved_count} gigs to database"
            total_gigs += saved_count
            successful_venues += 1
          else
            puts "⚠️ No valid gigs found"
            failed_venues << { venue: venue.name, reason: "No valid gigs" }
          end
        else
          puts "❌ No gigs found"
          failed_venues << { venue: venue.name, reason: "No gigs found" }
        end

      rescue => e
        puts "❌ Error: #{e.message}"
        failed_venues << { venue: venue.name, reason: e.message }
      end

      # Brief pause between venues
      sleep(2) unless index == venues.count - 1
    end

    puts "\n📊 SCRAPING SUMMARY:"
    puts "✅ Successful venues: #{successful_venues}/#{venues.count}"
    puts "📊 Total gigs found: #{total_gigs}"
    puts "❌ Failed venues: #{failed_venues.count}"

    if failed_venues.any?
      puts "\n❌ FAILED VENUES:"
      failed_venues.each_with_index do |failure, i|
        puts "#{i+1}. #{failure[:venue]} - #{failure[:reason]}"
      end
    end

    puts "\n🎉 Scraping complete!"
  end
end
