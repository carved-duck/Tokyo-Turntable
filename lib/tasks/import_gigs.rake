namespace :import do
  desc "Import gigs from TokyoGigGuide JSON data into database"
  task :gigs => :environment do
    puts "🎵 IMPORTING TOKYOGIGGUIDE GIGS TO DATABASE"
    puts "=" * 50

    json_file = Rails.root.join('db', 'data', 'gigs.json')

    unless File.exist?(json_file)
      puts "❌ ERROR: #{json_file} not found!"
      puts "Run 'rails scrape:gigs' first to create the JSON data."
      exit 1
    end

    # Load JSON data
    puts "📖 Loading gigs from #{json_file}..."
    data = JSON.parse(File.read(json_file))
    gigs_data = data['data'] || []

    puts "📊 Found #{gigs_data.count} gigs in JSON file"

    imported_count = 0
    skipped_count = 0
    error_count = 0

    # Get default user for gigs
    default_user = User.first || User.create!(
      email: 'admin@tokyoturntable.com',
      password: 'password123',
      password_confirmation: 'password123'
    )

    gigs_data.each_with_index do |gig_data, index|
      begin
        # Parse date
        parsed_date = parse_gig_date(gig_data['date'])
        unless parsed_date
          puts "  ⚠️  Skipping gig #{index + 1}: invalid date '#{gig_data['date']}'"
          skipped_count += 1
          next
        end

        # Find or create venue
        venue = find_or_create_venue_from_gig(gig_data)
        unless venue
          puts "  ⚠️  Skipping gig #{index + 1}: could not find/create venue"
          skipped_count += 1
          next
        end

        # Check if gig already exists
        existing_gig = Gig.find_by(
          date: parsed_date,
          venue: venue,
          user: default_user
        )

        if existing_gig
          skipped_count += 1
          next
        end

                 # Create new gig
         gig = Gig.new(
           date: parsed_date,
           venue: venue,
           user: default_user,
           open_time: parse_time(gig_data['open_time']),
           start_time: parse_time(gig_data['start_time']),
           price: extract_price(gig_data) || 0  # Default to 0 if no price
         )

        if gig.save
          # Create bands for this gig
          create_bands_for_gig(gig, gig_data)
          imported_count += 1

          if (index + 1) % 50 == 0
            puts "  📊 Progress: #{index + 1}/#{gigs_data.count} processed"
          end
        else
          puts "  ❌ Failed to save gig #{index + 1}: #{gig.errors.full_messages.join(', ')}"
          error_count += 1
        end

      rescue => e
        puts "  ❌ Error processing gig #{index + 1}: #{e.message}"
        error_count += 1
      end
    end

    puts "\n✅ IMPORT COMPLETE!"
    puts "=" * 50
    puts "📊 Total gigs processed: #{gigs_data.count}"
    puts "✅ Successfully imported: #{imported_count}"
    puts "⚠️  Skipped (duplicates/invalid): #{skipped_count}"
    puts "❌ Errors: #{error_count}"
    puts "\n📈 Database totals:"
    puts "   Venues: #{Venue.count}"
    puts "   Gigs: #{Gig.count}"
    puts "   Bands: #{Band.count}"
  end

  private

  def parse_gig_date(date_string)
    return nil unless date_string.present?

    # Handle "May 28" format - assume current year
    if date_string.match(/\A[A-Za-z]{3} \d{1,2}\z/)
      begin
        Date.parse("#{date_string} #{Date.current.year}")
      rescue
        nil
      end
    else
      begin
        Date.parse(date_string)
      rescue
        nil
      end
    end
  end

  def parse_time(time_string)
    return nil unless time_string.present?

    # Handle "18:30" or "18.30" format
    cleaned_time = time_string.gsub('.', ':')

    begin
      Time.parse("2000-01-01 #{cleaned_time}").strftime('%H:%M')
    rescue
      nil
    end
  end

  def extract_price(gig_data)
    # Look for price in various fields
    price_sources = [
      gig_data['price'],
      gig_data['admission'],
      gig_data['ticket_price'],
      gig_data['cost']
    ].compact

    price_sources.each do |source|
      # Extract numbers from price strings
      numbers = source.to_s.scan(/\d+/)
      return numbers.first.to_i if numbers.any?
    end

    nil
  end

  def find_or_create_venue_from_gig(gig_data)
    venue_name = gig_data['live_house'] || gig_data['venue'] || gig_data['location']
    return nil unless venue_name.present?

    # Clean venue name
    clean_name = venue_name.strip

    # Try to find existing venue
    venue = Venue.find_by('name ILIKE ?', clean_name)

         # Create new venue if not found
     unless venue
       venue = Venue.create!(
         name: clean_name,
         address: 'Tokyo, Japan', # Default address
         website: nil, # Will be populated later if needed
         email: 'info@venue.com', # Default email
         neighborhood: 'Tokyo', # Default neighborhood
         details: 'Venue details to be updated' # Default details
       )
     end

    venue
  end

  def create_bands_for_gig(gig, gig_data)
    # Extract band names from the gig name/title
    band_names = extract_band_names_from_gig(gig_data)

    band_names.each do |band_name|
      band = find_or_create_band(band_name)

      # Create association between band and gig (you might need a join table)
      # For now, we'll assume bands are stored as a simple association
      # You may need to adjust this based on your actual schema
    end
  end

  def extract_band_names_from_gig(gig_data)
    name = gig_data['name'] || ''

    # Simple extraction - split on common separators
    separators = [' / ', ', ', ' + ', ' & ', ' with ', ' ft. ', ' featuring ']

    band_names = [name]
    separators.each do |sep|
      band_names = band_names.flat_map { |n| n.split(sep) }
    end

    # Clean and filter band names
    band_names.map(&:strip)
              .reject(&:blank?)
              .reject { |name| name.length < 2 }
              .uniq
  end

  def find_or_create_band(band_name)
    clean_name = band_name.strip

    # Try to find existing band
    band = Band.find_by('name ILIKE ?', clean_name)

         # Create new band if not found
     unless band
       band = Band.create!(
         name: clean_name,
         hometown: 'Tokyo, Japan', # Default
         email: 'contact@band.com', # Default
         genre: 'Rock' # Default genre
       )
     end

    band
  end
end
