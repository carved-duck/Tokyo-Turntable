namespace :db do
  desc "Restore data from backup JSON files"
  task restore_from_backup: :environment do
    require 'json'

    puts '🔄 Starting data restoration...'

    # Read the backup file
    backup_file = Rails.root.join('db/data/proven_venues_selenium_test.json')
    data = JSON.parse(File.read(backup_file))

    puts "📊 Found #{data.length} venue records in backup"

    # Create a default user for the gigs
    default_user = User.find_or_create_by(email: 'scraper@tokyo-turntable.com') do |user|
      user.username = 'scraper'
      user.address = 'Tokyo'
      user.password = 'password123'
      user.password_confirmation = 'password123'
    end

    puts '👤 Default user created/found'

    restored_venues = 0
    restored_gigs = 0

    data.each_with_index do |venue_data, index|
      begin
        venue_name = venue_data['venue_name'] || venue_data['name']
        next unless venue_name

        # Create venue
        venue = Venue.find_or_create_by(name: venue_name) do |v|
          v.address = 'Tokyo'
          v.email = "info@#{venue_name.downcase.gsub(/[^a-z0-9]/, '')}.com"
          v.neighborhood = 'Tokyo'
          v.details = 'Restored from backup'
          v.website = venue_data['url'] if venue_data['url']
        end

        restored_venues += 1 if venue.persisted?

        # Create gigs if they exist
        if venue_data['gigs'] && venue_data['gigs'].any?
          venue_data['gigs'].each do |gig_data|
            begin
              date = Date.parse(gig_data['date'].to_s) rescue Date.current + 1.week

              gig = Gig.find_or_create_by(venue: venue, date: date) do |g|
                g.open_time = gig_data['time'] || '19:00'
                g.start_time = gig_data['start_time'] || '19:30'
                g.price = gig_data['price'] || '3000'
                g.user = default_user
              end

              if gig.persisted?
                restored_gigs += 1

                # Create band if title exists
                if gig_data['title'].present?
                  band = Band.find_or_create_by(name: gig_data['title']) do |b|
                    b.genre = 'Rock'
                    b.hometown = 'Tokyo'
                    b.email = "info@#{gig_data['title'].downcase.gsub(/[^a-z0-9]/, '')}.com"
                  end

                  # Create booking to link band and gig
                  Booking.find_or_create_by(gig: gig, band: band)
                end
              end
            rescue => e
              puts "  ⚠️ Gig error: #{e.message}"
            end
          end
        end

        puts "  ✅ #{venue_name} (#{venue_data['gigs']&.length || 0} gigs)" if index % 10 == 0

      rescue => e
        puts "  ❌ Venue error: #{e.message}"
      end
    end

    puts ""
    puts "🎉 RESTORATION COMPLETE!"
    puts "📊 Restored #{restored_venues} venues"
    puts "🎵 Restored #{restored_gigs} gigs"
    puts "🎸 Restored #{Band.count} bands"
  end
end
