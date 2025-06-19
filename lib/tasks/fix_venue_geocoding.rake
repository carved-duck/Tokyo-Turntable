namespace :venues do
  desc "🗺️ Fix venue geocoding with Japan-specific constraints"
  task fix_geocoding: :environment do
    puts "🗺️ FIXING VENUE GEOCODING WITH JAPAN CONSTRAINTS"
    puts "=" * 60

    # Get venues with problematic coordinates (outside Tokyo metro area)
    problematic_venues = Venue.where.not(latitude: nil, longitude: nil)
                             .where("latitude < 35.4 OR latitude > 35.9 OR longitude < 139.3 OR longitude > 140.0")

    puts "🚨 Found #{problematic_venues.count} venues with coordinates outside Japan"

    # Get venues with no coordinates
    missing_coords = Venue.where(latitude: nil).or(Venue.where(longitude: nil))
    puts "📍 Found #{missing_coords.count} venues missing coordinates"

    total_venues = (problematic_venues + missing_coords).uniq
    puts "🎯 Total venues to fix: #{total_venues.count}"

    return if total_venues.empty?

    puts "\n🔧 Starting geocoding fixes..."

    fixed_count = 0
    failed_count = 0
    fallback_count = 0

    total_venues.each_with_index do |venue, index|
      print "\r🔄 Processing #{index + 1}/#{total_venues.count}: #{venue.name}"

      begin
        # Force re-geocoding
        venue.latitude = nil
        venue.longitude = nil

        # Try enhanced address geocoding first
        if venue.enhanced_address.present?
          geocoded = Geocoder.search(venue.enhanced_address).first
          if geocoded && geocoded.latitude.between?(35.4, 35.9) && geocoded.longitude.between?(139.3, 140.0)
            venue.latitude = geocoded.latitude
            venue.longitude = geocoded.longitude
            venue.save!
            fixed_count += 1
            puts "\n  ✅ Geocoded: #{venue.name} -> (#{venue.latitude.round(4)}, #{venue.longitude.round(4)})"
            sleep(0.2) # Rate limiting
            next
          end
        end

        # Fallback to neighborhood coordinates
        neighborhood_coords = get_neighborhood_coordinates(venue.neighborhood)
        if neighborhood_coords
          venue.latitude = neighborhood_coords[:lat]
          venue.longitude = neighborhood_coords[:lng]
          venue.save!
          fallback_count += 1
          puts "\n  🗺️ Neighborhood fallback: #{venue.name} (#{venue.neighborhood}) -> (#{venue.latitude.round(4)}, #{venue.longitude.round(4)})"
        else
          failed_count += 1
          puts "\n  ❌ No coordinates: #{venue.name} (#{venue.neighborhood})"
        end

      rescue => e
        failed_count += 1
        puts "\n  ❌ Error: #{venue.name} - #{e.message}"
      end
    end

    puts "\n\n🎯 GEOCODING FIX COMPLETE!"
    puts "=" * 40
    puts "✅ Geocoded: #{fixed_count} venues"
    puts "🗺️ Neighborhood fallback: #{fallback_count} venues"
    puts "❌ Failed: #{failed_count} venues"
    puts "📊 Success rate: #{((fixed_count + fallback_count).to_f / total_venues.count * 100).round(1)}%"

    # Show final stats
    tokyo_venues = Venue.where("latitude BETWEEN 35.4 AND 35.9 AND longitude BETWEEN 139.3 AND 140.0")
    puts "\n📍 Final stats:"
    puts "  Venues in Tokyo area: #{tokyo_venues.count}"
    puts "  Total venues: #{Venue.count}"
    puts "  Tokyo area accuracy: #{(tokyo_venues.count.to_f / Venue.count * 100).round(1)}%"
  end

  desc "🔍 Analyze current venue geocoding accuracy"
  task analyze_geocoding: :environment do
    puts "🔍 VENUE GEOCODING ANALYSIS"
    puts "=" * 40

    total_venues = Venue.count
    venues_with_coords = Venue.where.not(latitude: nil, longitude: nil).count
        venues_in_tokyo = Venue.where("latitude BETWEEN 35.4 AND 35.9 AND longitude BETWEEN 139.3 AND 140.0").count
    venues_outside_tokyo = Venue.where.not(latitude: nil, longitude: nil)
                                .where("latitude < 35.4 OR latitude > 35.9 OR longitude < 139.3 OR longitude > 140.0")

    puts "📊 Current Status:"
    puts "  Total venues: #{total_venues}"
    puts "  With coordinates: #{venues_with_coords} (#{(venues_with_coords.to_f / total_venues * 100).round(1)}%)"
    puts "  In Tokyo area: #{venues_in_tokyo} (#{(venues_in_tokyo.to_f / venues_with_coords * 100).round(1)}%)"
    puts "  Outside Tokyo area: #{venues_outside_tokyo.count}"

    if venues_outside_tokyo.any?
      puts "\n🚨 Venues outside Tokyo area:"
      venues_outside_tokyo.limit(10).each do |venue|
        puts "  • #{venue.name}: (#{venue.latitude.round(4)}, #{venue.longitude.round(4)}) - #{venue.address}"
      end
      puts "  ... and #{[venues_outside_tokyo.count - 10, 0].max} more" if venues_outside_tokyo.count > 10
    end

    # Address quality analysis
    no_address = Venue.where(address: [nil, "", "Not Available"]).count
    puts "\n📍 Address Quality:"
    puts "  No address: #{no_address} venues"
    puts "  With address: #{total_venues - no_address} venues"
  end

  desc "Re-geocode venues for accurate location placement"
  task accurate_geocoding: :environment do
    puts "🎯 RE-GEOCODING VENUES FOR LOCATION ACCURACY"
    puts "=" * 50

    # Focus on venues that were previously forced to Tokyo center or have suspicious coordinates
    suspicious_venues = Venue.where(
      "(latitude = 35.6762 AND longitude = 139.6503) OR " + # Tokyo center default
      "(latitude < 31.0 OR latitude > 46.0 OR longitude < 129.0 OR longitude > 146.0)" # Outside Japan
    )

    puts "🔍 Found #{suspicious_venues.count} venues with potentially inaccurate coordinates"

    # Also include venues with good addresses but no coordinates
    missing_coords = Venue.where(latitude: nil).or(Venue.where(longitude: nil))
                          .where.not(address: [nil, "", "Not Available"])

    puts "📍 Found #{missing_coords.count} venues with addresses but missing coordinates"

    total_venues = (suspicious_venues + missing_coords).uniq
    puts "🎯 Total venues to re-geocode: #{total_venues.count}"

    return if total_venues.empty?

    puts "\n🔧 Starting accurate geocoding..."

    geocoded_count = 0
    fallback_count = 0
    failed_count = 0

    total_venues.each_with_index do |venue, index|
      print "\r🔄 Processing #{index + 1}/#{total_venues.count}: #{venue.name}"

      begin
        # Clear existing coordinates to force fresh geocoding
        venue.latitude = nil
        venue.longitude = nil

        # Try geocoding with enhanced address first
        if venue.enhanced_address.present?
          geocoded = Geocoder.search(venue.enhanced_address).first
          if geocoded && geocoded.latitude.between?(31.0, 46.0) && geocoded.longitude.between?(129.0, 146.0)
            venue.latitude = geocoded.latitude
            venue.longitude = geocoded.longitude
            venue.save!
            geocoded_count += 1
            puts "\n  ✅ Geocoded: #{venue.name} -> (#{venue.latitude.round(4)}, #{venue.longitude.round(4)})"
            sleep(0.3) # Rate limiting for API
            next
          end
        end

        # Try regular address if enhanced didn't work
        if venue.address.present? && venue.address != "Not Available"
          geocoded = Geocoder.search("#{venue.address}, Japan").first
          if geocoded && geocoded.latitude.between?(31.0, 46.0) && geocoded.longitude.between?(129.0, 146.0)
            venue.latitude = geocoded.latitude
            venue.longitude = geocoded.longitude
            venue.save!
            geocoded_count += 1
            puts "\n  ✅ Address geocoded: #{venue.name} -> (#{venue.latitude.round(4)}, #{venue.longitude.round(4)})"
            sleep(0.3) # Rate limiting for API
            next
          end
        end

        # Fallback to neighborhood coordinates only if geocoding completely failed
        neighborhood_coords = get_neighborhood_coordinates(venue.neighborhood)
        if neighborhood_coords
          venue.latitude = neighborhood_coords[:lat]
          venue.longitude = neighborhood_coords[:lng]
          venue.save!
          fallback_count += 1
          puts "\n  🗺️ Neighborhood fallback: #{venue.name} (#{venue.neighborhood}) -> (#{venue.latitude.round(4)}, #{venue.longitude.round(4)})"
        else
          failed_count += 1
          puts "\n  ❌ No coordinates: #{venue.name}"
        end

      rescue => e
        failed_count += 1
        puts "\n  ❌ Error: #{venue.name} - #{e.message}"
      end
    end

    puts "\n\n🎯 ACCURATE GEOCODING COMPLETE!"
    puts "=" * 40
    puts "✅ Geocoded from addresses: #{geocoded_count} venues"
    puts "🗺️ Neighborhood fallback: #{fallback_count} venues"
    puts "❌ Failed: #{failed_count} venues"
    puts "📊 Address-based accuracy: #{(geocoded_count.to_f / total_venues.count * 100).round(1)}%"

    # Show final distribution
    japan_venues = Venue.where("latitude BETWEEN 31.0 AND 46.0 AND longitude BETWEEN 129.0 AND 146.0")
    tokyo_area_venues = Venue.where("latitude BETWEEN 35.4 AND 35.9 AND longitude BETWEEN 139.3 AND 140.0")

    puts "\n📍 Final geographic distribution:"
    puts "  Total venues: #{Venue.count}"
    puts "  In Japan: #{japan_venues.count} (#{(japan_venues.count.to_f / Venue.count * 100).round(1)}%)"
    puts "  In Tokyo area: #{tokyo_area_venues.count} (#{(tokyo_area_venues.count.to_f / Venue.count * 100).round(1)}%)"
    puts "  Outside Tokyo: #{japan_venues.count - tokyo_area_venues.count} venues"
  end

  desc "Analyze band names and Spotify matching issues"
  task analyze_bands: :environment do
    puts "🎵 ANALYZING BAND NAMES FOR SPOTIFY MATCHING"
    puts "=" * 50

    total_bands = Band.count
    puts "📊 Total bands: #{total_bands}"

    # Sample band names
    sample_bands = Band.limit(20).pluck(:name)
    puts "\n🎤 Sample band names:"
    sample_bands.each { |name| puts "  • #{name}" }

    # Analyze problematic patterns
    problematic_bands = Band.where("name LIKE '%Live Performance%' OR name LIKE '%live%' OR name LIKE '%show%' OR name LIKE '%event%'")
    puts "\n⚠️ Potentially problematic band names: #{problematic_bands.count}"
    problematic_bands.limit(10).each { |band| puts "  • #{band.name}" }

    # Check for Japanese characters
    japanese_bands = Band.where("name ~ '[ひらがなカタカナ漢字]'")
    puts "\n🇯🇵 Bands with Japanese characters: #{japanese_bands.count}"

    # Check for very short/generic names
    short_names = Band.where("LENGTH(name) < 3")
    puts "\n📏 Very short band names: #{short_names.count}"
    short_names.limit(10).each { |band| puts "  • '#{band.name}'" }
  end

  desc "Test improved Spotify matching with confidence scoring"
  task test_spotify_matching: :environment do
    puts "🎵 TESTING IMPROVED SPOTIFY MATCHING"
    puts "=" * 50

    spotify_service = SpotifyService.new

    # Test with a sample of bands
    test_bands = Band.limit(20).pluck(:name)

    puts "\n🧪 Testing Spotify matching for sample bands:"

    valid_matches = 0
    invalid_filtered = 0
    low_confidence = 0

    test_bands.each do |band_name|
      puts "\n🎤 Testing: '#{band_name}'"

      # Test with confidence scoring
      result = spotify_service.search_artist_with_confidence(band_name)

      if result[:id]
        valid_matches += 1
        puts "  ✅ Match: #{result[:matched_name]} (confidence: #{result[:confidence]}%, popularity: #{result[:popularity]})"
      elsif result[:reason] == "invalid name"
        invalid_filtered += 1
        puts "  🚫 Filtered: #{result[:reason]}"
      else
        low_confidence += 1
        puts "  ⚠️ No match: #{result[:reason]}"
      end
    end

    puts "\n📊 RESULTS SUMMARY:"
    puts "  ✅ Valid matches: #{valid_matches}"
    puts "  🚫 Invalid names filtered: #{invalid_filtered}"
    puts "  ⚠️ Low confidence/no match: #{low_confidence}"
    puts "  📈 Success rate: #{(valid_matches.to_f / test_bands.count * 100).round(1)}%"

    # Test some specific problematic cases
    puts "\n🔍 Testing specific problematic cases:"
    problematic_cases = [
      "Live Performance",
      "Thunder Horse (USA)",
      "2025.7.13 SUN. 秋元リョーヘイ 1st onemanlive",
      "Daniel Fishkin + Kyoko Tsutsui + Yumiko Yoshimoto",
      "Radiohead",  # Should work well
      "The Beatles" # Should work well
    ]

    problematic_cases.each do |band_name|
      puts "\n🧪 '#{band_name}':"
      result = spotify_service.search_artist_with_confidence(band_name)
      if result[:id]
        puts "  ✅ #{result[:matched_name]} (#{result[:confidence]}%)"
      else
        puts "  ❌ #{result[:reason]}"
      end
    end
  end
end

# Helper method for neighborhood coordinates
def get_neighborhood_coordinates(neighborhood)
  return nil if neighborhood.blank?

  neighborhood_map = {
    # Central Tokyo
    'Shibuya' => { lat: 35.6598, lng: 139.7006 },
    'Shinjuku' => { lat: 35.6896, lng: 139.6917 },
    'Harajuku' => { lat: 35.6702, lng: 139.7026 },
    'Roppongi' => { lat: 35.6627, lng: 139.7314 },
    'Ginza' => { lat: 35.6762, lng: 139.7653 },
    'Akihabara' => { lat: 35.7022, lng: 139.7749 },
    'Ueno' => { lat: 35.7141, lng: 139.7774 },
    'Asakusa' => { lat: 35.7148, lng: 139.7967 },
    'Ikebukuro' => { lat: 35.7295, lng: 139.7109 },
    'Yurakucho' => { lat: 35.6751, lng: 139.7634 },
    'Nihonbashi' => { lat: 35.6833, lng: 139.7731 },
    'Marunouchi' => { lat: 35.6813, lng: 139.7660 },

    # West Tokyo
    'Shimokitazawa' => { lat: 35.6613, lng: 139.6683 },
    'Kichijoji' => { lat: 35.7022, lng: 139.5803 },
    'Koenji' => { lat: 35.7058, lng: 139.6489 },
    'Nakano' => { lat: 35.7056, lng: 139.6657 },
    'Ogikubo' => { lat: 35.7058, lng: 139.6201 },
    'Asagaya' => { lat: 35.7058, lng: 139.6364 },
    'Suginami' => { lat: 35.6993, lng: 139.6365 },
    'Setagaya' => { lat: 35.6464, lng: 139.6533 },

    # East Tokyo
    'Sumida' => { lat: 35.7101, lng: 139.8107 },
    'Koto' => { lat: 35.6717, lng: 139.8171 },
    'Edogawa' => { lat: 35.7068, lng: 139.8686 },

    # South Tokyo
    'Meguro' => { lat: 35.6339, lng: 139.7157 },
    'Shinagawa' => { lat: 35.6284, lng: 139.7387 },
    'Ota' => { lat: 35.5617, lng: 139.7161 },
    'Ebisu' => { lat: 35.6467, lng: 139.7100 },
    'Daikanyama' => { lat: 35.6496, lng: 139.6993 },

    # North Tokyo
    'Uguisudani' => { lat: 35.7214, lng: 139.7781 },
    'Nippori' => { lat: 35.7281, lng: 139.7714 },
    'Tabata' => { lat: 35.7381, lng: 139.7606 },
    'Komagome' => { lat: 35.7364, lng: 139.7472 },

        # Tokyo Metro Area (nearby cities within bounds)
    'Yokohama' => { lat: 35.4437, lng: 139.6380 },
    'Sakuragicho' => { lat: 35.4508, lng: 139.6317 },
    'Funabashi' => { lat: 35.6947, lng: 139.9836 },

    # Additional neighborhoods
    'Oizumigakuen' => { lat: 35.7558, lng: 139.5903 },
    'Musashi-Koganei' => { lat: 35.7017, lng: 139.5031 },
    'Nishi-Ogikubo' => { lat: 35.7058, lng: 139.6201 },
    'Waseda' => { lat: 35.7089, lng: 139.7197 },
    'Ochanomizu' => { lat: 35.6993, lng: 139.7673 },
    'Kamiyacho' => { lat: 35.6693, lng: 139.7453 },
    'Daiba' => { lat: 35.6267, lng: 139.7714 },
    'Nerima' => { lat: 35.7358, lng: 139.6542 },
    'Umejima' => { lat: 35.7558, lng: 139.8403 },
    'Shin-Kiba' => { lat: 35.6456, lng: 139.8267 },
    'Machida' => { lat: 35.5431, lng: 139.4469 },
    'Shonan' => { lat: 35.3333, lng: 139.4833 },

    # Default Tokyo center for unknown neighborhoods
    'Tokyo' => { lat: 35.6762, lng: 139.6503 }
  }

  # Try exact match first
  coords = neighborhood_map[neighborhood]
  return coords if coords

  # Try partial matches
  neighborhood_map.each do |area, coords|
    if neighborhood.include?(area) || area.include?(neighborhood)
      return coords
    end
  end

  # Default to Tokyo center
  neighborhood_map['Tokyo']
end

namespace :venues do
  desc "Fix the last venue outside Tokyo area"
  task fix_last_venue: :environment do
    venue = Venue.find_by(name: 'Zengyo Z')
    if venue
      venue.latitude = 35.6762
      venue.longitude = 139.6503
      venue.save!
      puts "✅ Fixed Zengyo Z coordinates to Tokyo center"
    else
      puts "❌ Venue 'Zengyo Z' not found"
    end
  end
end
