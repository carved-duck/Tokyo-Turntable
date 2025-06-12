namespace :venues do
  desc "Comprehensive audit of venue database for duplicates and invalid data"
  task audit: :environment do
    puts "🔍 VENUE DATABASE AUDIT"
    puts "=" * 50

    puts "\n📊 BASIC STATS:"
    puts "  Total venues: #{Venue.count}"
    puts "  Venues with websites: #{Venue.where.not(website: [nil, '']).count}"
    puts "  Venues with gigs: #{Venue.joins(:gigs).distinct.count}"

    # 1. Check for duplicate websites
    puts "\n🔍 CHECKING FOR DUPLICATE WEBSITES..."
    duplicate_websites = []
    website_counts = Venue.where.not(website: [nil, '']).group(:website).count
    website_counts.select { |_, count| count > 1 }.each do |website, _|
      venues_with_site = Venue.where(website: website)
      duplicate_websites << {
        website: website,
        venues: venues_with_site.map { |v| { name: v.name, id: v.id, gigs: v.gigs.count } }
      }
    end

    puts "  Found #{duplicate_websites.count} websites with multiple venues"
    if duplicate_websites.any?
      duplicate_websites.each do |dup|
        puts "    #{dup[:website]}:"
        dup[:venues].each { |v| puts "      - #{v[:name]} (#{v[:gigs]} gigs, ID: #{v[:id]})" }
      end
    end

    # 2. Check for venues with invalid/suspicious websites
    puts "\n🔍 CHECKING FOR INVALID WEBSITES..."
    invalid_websites = []
    suspicious_patterns = [
      /facebook\.com/i, /instagram\.com/i, /twitter\.com/i, /tiktok\.com/i,
      /youtube\.com/i, /blogspot\.com/i, /blog/i, /shop/i, /restaurant/i,
      /cafe\.com/i, /hotel/i, /tabelog\.com/i, /gurunavi\.com/i, /hotpepper\.jp/i,
      /\.html$/i # Static HTML files often indicate dead sites
    ]

    Venue.where.not(website: [nil, '']).find_each do |venue|
      if suspicious_patterns.any? { |pattern| venue.website.match?(pattern) }
        invalid_websites << {
          name: venue.name,
          website: venue.website,
          gigs: venue.gigs.count,
          id: venue.id
        }
      end
    end

    puts "  Found #{invalid_websites.count} venues with suspicious websites"
    invalid_websites.first(10).each do |venue|
      puts "    #{venue[:name]}: #{venue[:website]} (#{venue[:gigs]} gigs)"
    end
    puts "    ... (showing first 10)" if invalid_websites.count > 10

    # 3. Check for venues with non-music keywords
    puts "\n🔍 CHECKING FOR NON-MUSIC VENUES..."
    non_music_keywords = [
      /restaurant/i, /cafe/i, /hotel/i, /shop/i, /store/i, /gallery/i,
      /museum/i, /school/i, /office/i, /temple/i, /shrine/i, /park/i,
      /レストラン/i, /カフェ/i, /ホテル/i, /ショップ/i, /美術館/i, /博物館/i
    ]

    non_music_venues = []
    Venue.find_each do |venue|
      if non_music_keywords.any? { |pattern| venue.name.match?(pattern) || venue.details&.match?(pattern) }
        non_music_venues << {
          name: venue.name,
          website: venue.website,
          gigs: venue.gigs.count,
          id: venue.id
        }
      end
    end

    puts "  Found #{non_music_venues.count} potentially non-music venues"
    non_music_venues.first(10).each do |venue|
      puts "    #{venue[:name]}: #{venue[:website]} (#{venue[:gigs]} gigs)"
    end
    puts "    ... (showing first 10)" if non_music_venues.count > 10

    # 4. Check for venues with very similar names (potential Japanese/English duplicates)
    puts "\n🔍 CHECKING FOR SIMILAR NAMES..."
    similar_names = []
    venue_names = Venue.pluck(:name, :id, :website).map { |name, id, website| { name: name, id: id, website: website } }

    venue_names.each_with_index do |venue1, i|
      venue_names[(i+1)..-1].each do |venue2|
        # Check for name similarity (ignoring case and common variations)
        name1_clean = venue1[:name].downcase.gsub(/[^\w\s]/, '').gsub(/\s+/, ' ').strip
        name2_clean = venue2[:name].downcase.gsub(/[^\w\s]/, '').gsub(/\s+/, ' ').strip

        # Simple similarity check
        if name1_clean.include?(name2_clean) || name2_clean.include?(name1_clean) ||
           (name1_clean.length > 5 && name2_clean.length > 5 &&
            (name1_clean[0..4] == name2_clean[0..4] || name1_clean[-5..-1] == name2_clean[-5..-1]))
          similar_names << [venue1, venue2]
        end
      end
    end

    puts "  Found #{similar_names.count} pairs of venues with similar names"
    similar_names.first(5).each do |pair|
      v1, v2 = pair
      puts "    #{v1[:name]} vs #{v2[:name]}"
      puts "      URLs: #{v1[:website]} vs #{v2[:website]}"
    end
    puts "    ... (showing first 5)" if similar_names.count > 5

    # 5. Summary and recommendations
    puts "\n📋 AUDIT SUMMARY:"
    puts "  🔄 Duplicate websites: #{duplicate_websites.count}"
    puts "  ❌ Suspicious websites: #{invalid_websites.count}"
    puts "  🏢 Non-music venues: #{non_music_venues.count}"
    puts "  👯 Similar names: #{similar_names.count}"

    total_to_review = duplicate_websites.count + invalid_websites.count + non_music_venues.count
    puts "\n💡 RECOMMENDATIONS:"
    puts "  📊 Venues to review: ~#{total_to_review}"
    puts "  🎯 Potential database size after cleanup: ~#{Venue.count - total_to_review} venues"
    puts "  🔧 Next steps: Run 'rails venues:cleanup' to clean up identified issues"
  end

  desc "Show venues that have actually been scraped successfully"
  task scraped: :environment do
    puts "🎵 VENUES WITH GIGS (Successfully Scraped)"
    puts "=" * 50

    venues_with_gigs = Venue.joins(:gigs).group(:id, :name, :website).count
    sorted_venues = venues_with_gigs.sort_by { |_, gig_count| -gig_count }

    puts "Found #{sorted_venues.count} venues with gigs:\n"
    sorted_venues.each do |(id, name, website), gig_count|
      puts "  #{name}: #{gig_count} gigs"
      puts "    URL: #{website}"
      puts "    ID: #{id}"
      puts ""
    end
  end
end
