namespace :venues do
  desc "Populate venues from venue_links.json file"
  task populate_from_links: :environment do
    require 'json'
    require 'uri'
    require 'net/http'

    puts '🏢 POPULATING VENUES FROM VENUE LINKS'
    puts '===================================='

    # Read the venue links file
    links_file = Rails.root.join('db/data/venue_links.json')
    unless File.exist?(links_file)
      puts "❌ ERROR: venue_links.json not found at #{links_file}"
      exit 1
    end

    venue_data = JSON.parse(File.read(links_file))
    venue_links = venue_data['venue_detail_urls']
    puts "📋 Found #{venue_links.length} venue links"

    created_venues = 0
    skipped_venues = 0
    failed_venues = 0

    venue_links.each_with_index do |link, index|
      begin
        # Extract venue info from URL
        # URL format: https://www.tokyogigguide.com/en/gigs/venue/ID-venue-name
        url_parts = link.split('/')
        venue_slug = url_parts.last
        venue_id = venue_slug.split('-').first
        venue_name_parts = venue_slug.split('-')[1..-1]

        # Handle edge cases where venue name might be empty or just numbers
        if venue_name_parts.empty? || venue_name_parts.all? { |part| part.match?(/^\d+$/) }
          venue_name = "Venue #{venue_id}"
        else
          venue_name = venue_name_parts.join(' ').titleize
        end

        # Skip if venue already exists
        if Venue.exists?(name: venue_name)
          puts "[#{index + 1}/#{venue_links.length}] ⏭️  SKIP: #{venue_name} (already exists)"
          skipped_venues += 1
          next
        end

        puts "[#{index + 1}/#{venue_links.length}] 🏗️  Creating: #{venue_name}"

        # Create venue with basic info
        venue = Venue.create!(
          name: venue_name,
          address: "Tokyo, Japan", # Default address
          neighborhood: "Tokyo", # Default neighborhood
          website: link,
          email: "info@#{venue_name.downcase.gsub(/[^a-z0-9]/, '')}.com", # Placeholder email
          details: "Live music venue in Tokyo"
        )

        puts "    ✅ Created venue: #{venue.name}"
        created_venues += 1

      rescue => e
        puts "[#{index + 1}/#{venue_links.length}] ❌ ERROR creating venue from #{link}: #{e.message}"
        failed_venues += 1
      end

      # Brief pause to be respectful
      sleep(0.1) if index % 50 == 0
    end

    puts "\n🏁 VENUE POPULATION COMPLETE!"
    puts "="*40
    puts "✅ Created: #{created_venues} venues"
    puts "⏭️  Skipped: #{skipped_venues} venues (already existed)"
    puts "❌ Failed: #{failed_venues} venues"
    puts "📊 Total venues in database: #{Venue.count}"
    puts "\n🚀 Ready to run scraping tasks!"
  end

  desc "Update venue details from Tokyo Gig Guide"
  task enhance_venue_details: :environment do
    puts '🔍 ENHANCING VENUE DETAILS FROM TOKYO GIG GUIDE'
    puts '=============================================='

    venues_to_update = Venue.where(address: "Tokyo, Japan").limit(50)
    puts "📋 Found #{venues_to_update.count} venues to enhance"

    updated_venues = 0
    failed_venues = 0

    venues_to_update.each_with_index do |venue, index|
      begin
        puts "[#{index + 1}/#{venues_to_update.count}] 🔍 Enhancing: #{venue.name}"

        # Try to extract more details from the venue's Tokyo Gig Guide page
        if venue.website&.include?('tokyogigguide.com')
          # This would require scraping the venue page for details
          # For now, just update with better default values

          # Guess neighborhood from venue name
          neighborhood = case venue.name.downcase
          when /shibuya/ then "Shibuya"
          when /shinjuku/ then "Shinjuku"
          when /harajuku/ then "Harajuku"
          when /roppongi/ then "Roppongi"
          when /ikebukuro/ then "Ikebukuro"
          when /koenji/ then "Koenji"
          when /shimokitazawa/ then "Shimokitazawa"
          when /akihabara/ then "Akihabara"
          when /ueno/ then "Ueno"
          when /asakusa/ then "Asakusa"
          else "Tokyo"
          end

          venue.update!(
            neighborhood: neighborhood,
            address: "#{neighborhood}, Tokyo, Japan",
            details: "Live music venue in #{neighborhood}, Tokyo"
          )

          puts "    ✅ Updated: #{venue.name} -> #{neighborhood}"
          updated_venues += 1
        end

      rescue => e
        puts "    ❌ ERROR updating #{venue.name}: #{e.message}"
        failed_venues += 1
      end

      sleep(0.1) if index % 20 == 0
    end

    puts "\n🏁 VENUE ENHANCEMENT COMPLETE!"
    puts "="*40
    puts "✅ Updated: #{updated_venues} venues"
    puts "❌ Failed: #{failed_venues} venues"
  end
end
