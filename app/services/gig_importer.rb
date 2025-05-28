class GigImporter
  require 'json'
  # Assuming Venue, Band, Gig, User, Booking models are available in your Rails environment
  # No need to require 'open-uri', 'nokogiri', 'ferrum', 'uri', 'fileutils' here,
  # as VenueScraper handles the web scraping part.

  def import_gigs_from_json()
    filepath = "./db/data/gigs.json"
    unless File.exist?(filepath)
      puts "ERROR: JSON file not found at #{filepath}"
      return
    end

    puts "--- Starting import from #{filepath} ---"
    raw_data = File.read(filepath)
    parsed_data = JSON.parse(raw_data)

    gigs_data = parsed_data['data']

    if gigs_data.nil? || !gigs_data.is_a?(Array)
      puts "ERROR: 'data' key not found or not an array in JSON file."
      return
    end

    puts "Found #{gigs_data.count} gigs in JSON to import."

    gigs_data.each do |gig_attributes|
      begin # Wrap the entire gig processing in a begin-rescue for individual gig errors
        # Make bands
        full_gig_name = gig_attributes['name'].to_s.strip
        puts "working on #{full_gig_name}"
        band_names = full_gig_name.split(', ').map(&:strip).reject(&:empty?)
        associated_bands = []
        band_names.each do |b_name|
          band = Band.find_or_create_by!(name: b_name) do |b|
            b.genre = gig_attributes['category']&.split(',')&.first&.strip # Use first genre from category
            b.email = "#{b_name}@gmail.com"
            b.hometown = "Osaka" # Default or scrape this later
          end
          associated_bands << band
          puts "  Band: '#{band.name}' (ID: #{band.id}) #{band.new_record? ? 'CREATED' : 'UPDATED'}."
        end

        # --- MODIFIED LOGIC: Make venue ---
        venue_name = gig_attributes['live_house'].to_s.strip

        if venue_name.empty?
          puts "  WARNING: Gig has no venue name. Skipping venue creation/lookup for this gig."
          next # Skip to the next gig if no venue name
        end

        venue = Venue.find_by(name: venue_name) # Attempt to find existing venue

        if venue
          puts "  Venue: '#{venue.name}' (ID: #{venue.id}) found in database. Using existing record."
        else
          # If venue not found, create it using the gig_attributes (your "old way")
          puts "  Venue: '#{venue_name}' not found in database. Creating it from gig info."
          venue = Venue.find_or_create_by!(name: venue_name) do |v|
            v.neighborhood = gig_attributes['area'] # This will be from the gig's JSON
            v.address = "#{gig_attributes['area'] || 'Unknown Area'}, Tokyo" # This will be from the gig's JSON
            v.email = "#{venue_name}@gmail.com" # Default email
            v.details = "fill in later" # Default details
            # If you have more attributes from gig_attributes you want to use as fallback, add them here.
          end
          puts "  Venue: '#{venue.name}' (ID: #{venue.id}) CREATED from gig info."
        end
        # --- END MODIFIED LOGIC ---

        # Ensure a venue object exists before proceeding with gig creation
        unless venue
          puts "  ERROR: Failed to find or create venue for gig '#{full_gig_name}'. Skipping gig creation."
          next # Skip to the next gig
        end

        # Make gig
        adv_price = gig_attributes['adv_price'].to_s.strip
        door_price = gig_attributes['door_price'].to_s.strip
        price_string = "See at venue"
        if adv_price.present? && door_price.present?
          price_string = "#{adv_price} / #{door_price}"
        elsif adv_price.present?
          price_string = adv_price
        elsif door_price.present?
          price_string = door_price
        end

        gig_date = Date.parse(gig_attributes['date'])
        gig_open_time = gig_attributes['open_time'].to_s.strip

        # Assuming User.first is a valid user for associating gigs
        user = User.first || User.create!(email: "default@example.com", password: "password", password_confirmation: "password") # Create a default user if none exists
        puts "  Using User: #{user.email} (ID: #{user.id})" if user.new_record?

        gig = Gig.find_or_initialize_by(
            date: gig_date,
            open_time: gig_open_time,
            venue: venue # Associate the found/created venue
          ) do |g|
            g.start_time = "30 after open_time" # Consider parsing this into a real time
            g.price = price_string
            g.user = user
            # Add any other gig attributes here
          end

        if gig.save
            status = gig.new_record? ? 'CREATED' : 'UPDATED'
            puts "  #{status} Gig (ID: #{gig.id}): '#{full_gig_name}' at #{gig.venue.name} on #{gig.date.strftime('%Y-%m-%d')} #{gig.open_time}"
        else
          puts "  ERROR importing #{full_gig_name}: #{gig.errors.full_messages.join(', ')}"
        end

        # Make bookings
        associated_bands.each do |band|
          Booking.find_or_create_by!(band: band, gig: gig)
          puts "  Booking created/ensured for '#{band.name}' on Gig ID #{gig.id}."
        end

      rescue => e
        puts "ERROR processing gig: #{gig_attributes.inspect} - #{e.message}"
        puts e.backtrace.join("\n") # Print full backtrace for detailed error info
      end
    end

    puts "--- Import process finished ---"
  end
end
