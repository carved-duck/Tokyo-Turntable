namespace :venues do
  desc "Extract and update real venue websites from backup data"
  task update_websites_from_backup: :environment do
    require 'json'

    puts '🔄 EXTRACTING REAL VENUE WEBSITES FROM BACKUP'
    puts '============================================='

    # Read the backup file with real venue websites
    backup_file = Rails.root.join('db/data/proven_venues_selenium_test.json')
    unless File.exist?(backup_file)
      puts "❌ ERROR: Backup file not found at #{backup_file}"
      exit 1
    end

    backup_data = JSON.parse(File.read(backup_file))
    puts "📊 Found #{backup_data.length} gig records in backup"

    # Extract unique venues with their real websites
    venue_websites = {}
    backup_data.each do |gig|
      venue_name = gig['venue']
      source_url = gig['source_url']

      if venue_name && source_url && !source_url.include?('tokyogigguide')
        venue_websites[venue_name] = source_url
      end
    end

    puts "🏢 Found #{venue_websites.keys.length} unique venues with real websites:"
    venue_websites.each do |name, url|
      puts "  - #{name}: #{url}"
    end

    # Update venues in database
    updated_venues = 0
    created_venues = 0

    venue_websites.each do |venue_name, website_url|
      # Try to find existing venue by name (fuzzy matching)
      venue = Venue.find_by(name: venue_name)

      # If not found by exact name, try fuzzy matching
      unless venue
        # Try case-insensitive search
        venue = Venue.where("LOWER(name) = ?", venue_name.downcase).first
      end

      # If still not found, try partial matching
      unless venue
        venue = Venue.where("name ILIKE ?", "%#{venue_name.split.first}%").first
      end

      if venue
        # Update existing venue with real website
        old_website = venue.website
        venue.update!(website: website_url)
        puts "✅ Updated #{venue.name}: #{old_website} → #{website_url}"
        updated_venues += 1
      else
        # Create new venue if not found
        venue = Venue.create!(
          name: venue_name,
          website: website_url,
          address: "Tokyo, Japan", # Default address
          email: "contact@venue.com", # Default email
          neighborhood: "Tokyo", # Default neighborhood
          details: "Live music venue in Tokyo"
        )
        puts "🆕 Created new venue: #{venue_name} (#{website_url})"
        created_venues += 1
      end
    end

    puts "\n📊 WEBSITE UPDATE SUMMARY:"
    puts "✅ Updated existing venues: #{updated_venues}"
    puts "🆕 Created new venues: #{created_venues}"
    puts "🌐 Total venues with real websites: #{updated_venues + created_venues}"

    # Show current status
    real_website_count = Venue.where.not(website: [nil, ''])
                              .where('website NOT LIKE ?', '%tokyogigguide%')
                              .count

    puts "\n🎯 CURRENT DATABASE STATUS:"
    puts "📊 Total venues: #{Venue.count}"
    puts "🌐 Venues with real websites: #{real_website_count}"
    puts "📋 Venues with TokyoGigGuide URLs: #{Venue.where('website LIKE ?', '%tokyogigguide%').count}"

    puts "\n✅ Ready to scrape real venue websites!"
  end
end
