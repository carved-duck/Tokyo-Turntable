namespace :genres do
  desc "Reclassify all bands using improved genre detection"
  task reclassify: :environment do
    puts "🎼 RECLASSIFYING BAND GENRES"
    puts "=" * 50

    total_bands = Band.count
    updated_count = 0
    genre_changes = Hash.new(0)

    puts "📊 Processing #{total_bands} bands..."

    Band.find_each.with_index do |band, index|
      old_genre = band.genre
      new_genre = determine_genre_from_name(band.name)

      if old_genre != new_genre
        band.update!(genre: new_genre)
        genre_changes["#{old_genre} → #{new_genre}"] += 1
        updated_count += 1

        if updated_count % 100 == 0
          puts "  ✅ Updated #{updated_count} bands..."
        end
      end

      if (index + 1) % 500 == 0
        puts "  📈 Progress: #{index + 1}/#{total_bands} (#{((index + 1).to_f / total_bands * 100).round(1)}%)"
      end
    end

    puts ""
    puts "🎉 RECLASSIFICATION COMPLETE!"
    puts "📊 Updated #{updated_count}/#{total_bands} bands (#{(updated_count.to_f / total_bands * 100).round(1)}%)"

    if genre_changes.any?
      puts ""
      puts "📈 GENRE CHANGES:"
      genre_changes.sort_by { |_, count| -count }.each do |change, count|
        puts "  #{change}: #{count} bands"
      end
    end

    puts ""
    puts "🎼 NEW GENRE DISTRIBUTION:"
    Band.group(:genre).order(Arel.sql('COUNT(*) DESC')).count.each_with_index do |(genre, count), index|
      percentage = (count.to_f / total_bands * 100).round(1)
      puts "  #{index + 1}. #{genre}: #{count} bands (#{percentage}%)"
    end
  end

  desc "Update band genres using Spotify API"
  task spotify_update: :environment do
    puts "🎵 UPDATING BAND GENRES WITH SPOTIFY API"
    puts "=" * 50

    # Focus on bands that might actually be real artists (not "Unknown" generic entries)
    candidate_bands = Band.where.not(genre: "Unknown")
                         .where("LENGTH(name) > 2")
                         .where("name NOT ILIKE '%live%'")
                         .where("name NOT ILIKE '%show%'")
                         .where("name NOT ILIKE '%event%'")
                         .where("name NOT ILIKE '%performance%'")

    total_candidates = candidate_bands.count
    puts "📊 Processing #{total_candidates} candidate bands (filtering out obvious non-artists)..."

    spotify_service = SpotifyService.new
    updated_count = 0
    spotify_found_count = 0
    genre_changes = Hash.new(0)

    candidate_bands.find_each.with_index do |band, index|
      begin
        old_genre = band.genre

        # Try Spotify API
        genre_info = spotify_service.get_artist_genre_info(band.name)

        if genre_info && genre_info[:confidence] > 75 && genre_info[:primary_genre] != "Unknown"
          new_genre = genre_info[:primary_genre]
          spotify_found_count += 1

          if old_genre != new_genre
            band.update!(genre: new_genre)
            genre_changes["#{old_genre} → #{new_genre}"] += 1
            updated_count += 1
            puts "  🎵 #{band.name}: #{old_genre} → #{new_genre} (#{genre_info[:confidence]}% confidence)"
          end
        end

        # Progress updates
        if (index + 1) % 50 == 0
          puts "  📈 Progress: #{index + 1}/#{total_candidates} (#{((index + 1).to_f / total_candidates * 100).round(1)}%) - Found #{spotify_found_count} on Spotify"
        end

        # Rate limiting - be respectful to Spotify API
        sleep(0.2)

      rescue => e
        puts "  ⚠️ Error processing #{band.name}: #{e.message}"
        sleep(1) # Longer pause on error
      end
    end

    puts ""
    puts "🎉 SPOTIFY UPDATE COMPLETE!"
    puts "📊 Found #{spotify_found_count}/#{total_candidates} bands on Spotify (#{(spotify_found_count.to_f / total_candidates * 100).round(1)}%)"
    puts "📊 Updated #{updated_count} band genres"

    if genre_changes.any?
      puts ""
      puts "📈 GENRE CHANGES FROM SPOTIFY:"
      genre_changes.sort_by { |_, count| -count }.each do |change, count|
        puts "  #{change}: #{count} bands"
      end
    end

    puts ""
    puts "🎼 UPDATED GENRE DISTRIBUTION:"
    Band.group(:genre).order(Arel.sql('COUNT(*) DESC')).count.each_with_index do |(genre, count), index|
      percentage = (count.to_f / Band.count * 100).round(1)
      puts "  #{index + 1}. #{genre}: #{count} bands (#{percentage}%)"
    end
  end

  private

  def determine_genre_from_name(band_name)
    # Enhanced genre detection based on band name patterns and context
    name_lower = band_name.downcase.strip

    # Return Unknown for obviously non-musical content
    return "Unknown" if name_lower.match?(/live|show|event|performance|concert|festival|party|presents|featuring|vs\.|&|open mic|jam session|workshop|talk|lecture|exhibition/)

    # Electronic/DJ genres
    return "Electronic" if name_lower.match?(/\bdj\b|electronic|techno|house|ambient|edm|dubstep|trance|drum.?n.?bass|dnb|breakbeat|garage|minimal|acid|rave/)

    # Jazz and related
    return "Jazz" if name_lower.match?(/jazz|swing|blues|bebop|fusion|bossa.?nova|latin.?jazz|smooth.?jazz|big.?band|quartet|quintet|trio.*jazz/)

    # Hip-Hop and Rap
    return "Hip-Hop" if name_lower.match?(/hip.?hop|rap|mc\b|rapper|freestyle|trap|drill|grime/)

    # Classical and orchestral
    return "Classical" if name_lower.match?(/orchestra|symphony|classical|chamber|philharmonic|quartet.*classical|concerto|opera|baroque/)

    # Folk and acoustic
    return "Folk" if name_lower.match?(/folk|acoustic|singer.?songwriter|americana|country|bluegrass|celtic/)

    # Indie and alternative
    return "Indie" if name_lower.match?(/indie|underground|alternative|alt.?rock|shoegaze|dream.?pop|lo.?fi/)

    # Punk and hardcore
    return "Punk" if name_lower.match?(/punk|hardcore|emo|screamo|post.?punk|ska.?punk/)

    # Metal genres
    return "Metal" if name_lower.match?(/metal|death|black.*metal|doom|sludge|grind|core$|metalcore|deathcore/)

    # Pop and mainstream
    return "Pop" if name_lower.match?(/pop|idol|j.?pop|k.?pop|mainstream|commercial/)

    # Reggae and related
    return "Reggae" if name_lower.match?(/reggae|ska|dub|rastafari|jamaica/)

    # World music
    return "World" if name_lower.match?(/world|ethnic|traditional|cultural|african|latin|asian|middle.?eastern/)

    # Experimental and avant-garde
    return "Experimental" if name_lower.match?(/experimental|avant.?garde|noise|drone|ambient|soundscape|improvisation/)

    # R&B and Soul
    return "R&B" if name_lower.match?(/r&b|soul|funk|motown|neo.?soul|contemporary.?r&b/)

    # If band name is very short or generic, likely Unknown
    return "Unknown" if name_lower.length < 3 || name_lower.match?(/^(band|group|artist|music|sound|live|show)s?$/)

    # Japanese-specific patterns
    return "J-Rock" if name_lower.match?(/j.?rock|japanese.*rock|visual.?kei/)
    return "J-Pop" if name_lower.match?(/j.?pop|japanese.*pop/)

    # Only classify as Rock if there are actual rock-related keywords
    return "Rock" if name_lower.match?(/rock|guitar|band.*rock|classic.*rock|hard.*rock|soft.*rock|prog|progressive/)

    # Default to Unknown instead of Rock for unclassifiable bands
    "Unknown"
  end
end
