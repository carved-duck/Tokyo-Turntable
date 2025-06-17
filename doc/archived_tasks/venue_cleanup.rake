namespace :venues do
  desc "Clean up venue database by merging duplicates and removing non-music venues"
  task cleanup: :environment do
    puts "🧹 VENUE DATABASE CLEANUP"
    puts "=" * 50

    # Create backup before cleanup
    puts "\n📋 Creating backup..."
    backup_data = {
      total_venues: Venue.count,
      total_gigs: Gig.count,
      venues_with_gigs: Venue.joins(:gigs).distinct.count
    }
    puts "  Before cleanup: #{backup_data[:total_venues]} venues, #{backup_data[:total_gigs]} gigs"

    cleanup_summary = {
      duplicates_merged: 0,
      non_music_removed: 0,
      suspicious_websites_removed: 0,
      gigs_transferred: 0
    }

    # 1. Handle exact duplicate websites (same URL, different names)
    puts "\n🔄 MERGING DUPLICATE WEBSITES..."
    website_counts = Venue.where.not(website: [nil, '']).group(:website).count
    website_counts.select { |_, count| count > 1 }.each do |website, _|
      venues_with_site = Venue.where(website: website).order(:id)
      next if venues_with_site.count <= 1

      puts "  Merging venues for #{website}:"

      # Keep the venue with the most gigs, or the first one if tied
      keeper = venues_with_site.max_by { |v| v.gigs.count }
      duplicates = venues_with_site - [keeper]

      duplicates.each do |duplicate|
        puts "    Moving #{duplicate.gigs.count} gigs from '#{duplicate.name}' to '#{keeper.name}'"

        # Transfer gigs to keeper
        duplicate.gigs.update_all(venue_id: keeper.id)
        cleanup_summary[:gigs_transferred] += duplicate.gigs.count

        # Delete duplicate
        duplicate.destroy
        cleanup_summary[:duplicates_merged] += 1
      end
    end

    # 2. Handle known venue name duplicates (Den-atsu family)
    puts "\n🎯 HANDLING KNOWN DUPLICATES..."

    # Find Den-atsu variants
    den_atsu_venues = Venue.where("name ILIKE ?", "%den-atsu%")
      .or(Venue.where("name ILIKE ?", "%二万電圧%"))
      .or(Venue.where("name ILIKE ?", "%20000%"))
      .order(:id)

    if den_atsu_venues.count > 1
      puts "  Found #{den_atsu_venues.count} Den-atsu variants:"
      den_atsu_venues.each { |v| puts "    - #{v.name} (#{v.gigs.count} gigs, ID: #{v.id})" }

      # Keep the one with the most gigs and proper website
      keeper = den_atsu_venues.find { |v| v.website.present? && v.website.include?('den-atsu.com') }
      keeper ||= den_atsu_venues.max_by { |v| v.gigs.count }

      duplicates = den_atsu_venues - [keeper]
      duplicates.each do |duplicate|
        puts "    Moving #{duplicate.gigs.count} gigs from '#{duplicate.name}' to '#{keeper.name}'"
        duplicate.gigs.update_all(venue_id: keeper.id)
        cleanup_summary[:gigs_transferred] += duplicate.gigs.count
        duplicate.destroy
        cleanup_summary[:duplicates_merged] += 1
      end
    end

    # 3. Remove venues with clearly non-music websites
    puts "\n❌ REMOVING NON-MUSIC VENUES..."
    non_music_patterns = [
      /facebook\.com/i, /instagram\.com/i, /twitter\.com/i, /tiktok\.com/i,
      /tabelog\.com/i, /gurunavi\.com/i, /hotpepper\.jp/i,
      /hotel/i, /restaurant/i, /\.html$/i
    ]

    # Only remove venues WITHOUT gigs to be safe
    Venue.where(gigs: []).find_each do |venue|
      if venue.website.present? && non_music_patterns.any? { |pattern| venue.website.match?(pattern) }
        # Double-check it's not a music venue by name
        music_keywords = /live|music|concert|band|rock|jazz|club|stage|studio/i
        unless venue.name.match?(music_keywords)
          puts "    Removing: #{venue.name} (#{venue.website})"
          venue.destroy
          cleanup_summary[:suspicious_websites_removed] += 1
        end
      end
    end

    # 4. Remove obviously non-music venues by name (only if no gigs)
    puts "\n🏢 REMOVING NON-MUSIC VENUES BY NAME..."
    non_music_keywords = [
      /cafe|restaurant|hotel|shop|store|gallery|museum|school|office|temple|shrine|park/i,
      /カフェ|レストラン|ホテル|ショップ|美術館|博物館/i
    ]

    Venue.where(gigs: []).find_each do |venue|
      if non_music_keywords.any? { |pattern| venue.name.match?(pattern) }
        # Make sure it's not actually a music cafe/bar
        music_keywords = /live|music|concert|band|rock|jazz|bar|club|stage/i
        unless venue.name.match?(music_keywords) || venue.website&.match?(music_keywords)
          puts "    Removing: #{venue.name}"
          venue.destroy
          cleanup_summary[:non_music_removed] += 1
        end
      end
    end

    # 5. Final summary
    puts "\n📊 CLEANUP SUMMARY:"
    puts "  🔄 Duplicates merged: #{cleanup_summary[:duplicates_merged]}"
    puts "  🎵 Gigs transferred: #{cleanup_summary[:gigs_transferred]}"
    puts "  ❌ Non-music websites removed: #{cleanup_summary[:suspicious_websites_removed]}"
    puts "  🏢 Non-music venues removed: #{cleanup_summary[:non_music_removed]}"

    total_removed = cleanup_summary[:duplicates_merged] + cleanup_summary[:suspicious_websites_removed] + cleanup_summary[:non_music_removed]

    puts "\n🎯 FINAL STATS:"
    puts "  Before: #{backup_data[:total_venues]} venues"
    puts "  Removed: #{total_removed} venues"
    puts "  After: #{Venue.count} venues"
    puts "  Venues with gigs: #{Venue.joins(:gigs).distinct.count}"
    puts "  Total gigs: #{Gig.count}"

    puts "\n✅ Cleanup complete! Database is now cleaner and more focused on actual music venues."
  end

  desc "Show venues that need manual review (potential duplicates with gigs)"
  task review: :environment do
    puts "🔍 VENUES NEEDING MANUAL REVIEW"
    puts "=" * 50

    # Look for venues with similar names that both have gigs
    puts "\n🎵 Potential duplicates with gigs:"

    venues_with_gigs = Venue.joins(:gigs).group(:id, :name, :website).count
    venue_data = venues_with_gigs.map do |(id, name, website), gig_count|
      { id: id, name: name, website: website, gigs: gig_count }
    end

    # Look for similar names
    potential_duplicates = []
    venue_data.each_with_index do |venue1, i|
      venue_data[(i+1)..-1].each do |venue2|
        name1_clean = venue1[:name].downcase.gsub(/[^\w\s]/, '').strip
        name2_clean = venue2[:name].downcase.gsub(/[^\w\s]/, '').strip

        # More targeted similarity check
        if name1_clean.include?(name2_clean) || name2_clean.include?(name1_clean) ||
           (name1_clean.split.any? { |word| word.length > 3 && name2_clean.include?(word) })
          potential_duplicates << [venue1, venue2]
        end
      end
    end

    potential_duplicates.each do |pair|
      v1, v2 = pair
      puts "  🤔 #{v1[:name]} (#{v1[:gigs]} gigs) vs #{v2[:name]} (#{v2[:gigs]} gigs)"
      puts "     URLs: #{v1[:website]} vs #{v2[:website]}"
      puts "     IDs: #{v1[:id]} vs #{v2[:id]}"
      puts ""
    end

    puts "Found #{potential_duplicates.count} potential duplicate pairs to review manually."
  end

  desc "Aggressively clean venues with social media pages only (no gigs)"
  task aggressive_cleanup: :environment do
    puts "🧹 AGGRESSIVE VENUE CLEANUP"
    puts "=" * 50

    puts "\n📊 Before cleanup:"
    puts "  Total venues: #{Venue.count}"
    puts "  Venues with gigs: #{Venue.joins(:gigs).distinct.count}"

    removed_count = 0

    # Remove venues that only have social media pages and no gigs
    puts "\n❌ Removing social media only venues (no gigs)..."
    social_patterns = [/facebook\.com/i, /instagram\.com/i, /twitter\.com/i, /tiktok\.com/i]

    Venue.where(gigs: []).find_each do |venue|
      if venue.website.present? && social_patterns.any? { |pattern| venue.website.match?(pattern) }
        puts "    Removing: #{venue.name} (#{venue.website})"
        venue.destroy
        removed_count += 1
      end
    end

    # Remove venues with blog/static HTML pages (no gigs)
    puts "\n❌ Removing blog/static page venues (no gigs)..."
    static_patterns = [/blogspot\.com/i, /blog\.com/i, /\.html$/i, /\.htm$/i]

    Venue.where(gigs: []).find_each do |venue|
      if venue.website.present? && static_patterns.any? { |pattern| venue.website.match?(pattern) }
        # Don't remove if it has music keywords
        music_keywords = /live|music|concert|band|rock|jazz|club|stage|studio/i
        unless venue.name.match?(music_keywords)
          puts "    Removing: #{venue.name} (#{venue.website})"
          venue.destroy
          removed_count += 1
        end
      end
    end

    puts "\n📊 After cleanup:"
    puts "  Total venues: #{Venue.count}"
    puts "  Venues removed: #{removed_count}"
    puts "  Venues with gigs: #{Venue.joins(:gigs).distinct.count}"

    puts "\n✅ Aggressive cleanup complete!"
  end
end
