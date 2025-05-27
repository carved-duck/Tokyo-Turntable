# app/services/live_house_importer.rb
class LiveHouseImporter
  require 'json'

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
      # Make bands
      full_gig_name = gig_attributes['name'].to_s.strip
      puts "working on #{full_gig_name}"
      band_names = full_gig_name.split(', ').map(&:strip).reject(&:empty?)
      associated_bands = []
      band_names.each do |b_name|
        band = Band.find_or_create_by!(name: b_name) do |b|
          b.genre = gig_attributes['category']&.split(',')&.first&.strip # Use first genre from category
          b.email = "#{b_name}@gmail.com"
          b.hometown = "Osaka"
        end
        associated_bands << band
        puts "  Band: '#{band.name}' (ID: #{band.id}) #{band.new_record? ? 'CREATED' : 'UPDATED'}."
      end
      # Make venue
      venue_name = gig_attributes['live_house'].to_s.strip
      venue = Venue.find_or_create_by!(name: venue_name) do |v|
        v.neighborhood = gig_attributes['area']
        v.address = "#{gig_attributes['area'] || 'Unknown Area'}, Tokyo",
        v.email = "#{venue_name}@gmail.com",
        v.details = "fill in later"
      end
      puts "  Venue: '#{venue.name}' (ID: #{venue.id}) #{venue.new_record? ? 'CREATED' : 'UPDATED'}."
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

      gig_data = {
          date: gig_date,
          open_time: gig_open_time,
          start_time: "30 after open_time",
          price: price_string,
          venue: venue,
          user: User.first
        }
      gig = Gig.find_or_initialize_by(
          gig_data
        )
      if gig.save
          status = gig.new_record? ? 'CREATED' : 'UPDATED'
          puts "  #{status} Gig (ID: #{gig.id}): '#{full_gig_name}' at #{gig.venue.name} on #{gig.date.strftime('%Y-%m-%d')} #{gig.open_time}"
      end

      if gig.save
        puts "  Imported/Updated: #{gig.venue.name}"
      else
        puts "  ERROR importing #{gig_attributes['name']}: #{gig.errors.full_messages.join(', ')}"
      end
      # Make bookings
      associated_bands.each do |band|
        Booking.find_or_create_by!(band: band, gig: gig)
        puts "Booking created/ensured for '#{band.name}' on Gig ID #{gig.id}."
      end
    rescue => e
      puts "ERROR processing gig: #{gig_attributes.inspect} - #{e.message}"
    end

    puts "--- Import process finished ---"
  end
end
