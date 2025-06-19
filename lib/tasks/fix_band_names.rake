namespace :bands do
  desc "Test improved band name extraction on sample data"
  task test_extraction: :environment do
    puts "🧪 TESTING IMPROVED BAND NAME EXTRACTION"
    puts "=" * 60

    # Get some sample problematic band names from the database
    problematic_bands = Band.where("name LIKE '%live%' OR name LIKE '%show%' OR name LIKE '%event%' OR name LIKE '%2025%' OR name LIKE '%●%' OR name LIKE '%DJ：%'")
                           .limit(20)

    puts "📊 Testing #{problematic_bands.count} problematic band names..."
    puts

    scraper = UnifiedVenueScraper.new

    problematic_bands.each do |band|
      puts "🔍 Original: #{band.name}"

      # Test the new extraction methods
      gig_data = { title: band.name, artists: nil }
      extracted = scraper.send(:extract_band_names, gig_data)

      puts "   ✨ Extracted: #{extracted.join(', ')}"
      puts "   📝 Would be: #{extracted.first || 'Live Performance'}"
      puts
    end

    puts "🎯 Testing structured title extraction..."
    test_titles = [
      "Cornelius Live",
      "Live: Guitar Wolf",
      "Perfume ● Special Guest",
      "07/23 WED 矢野沙織カルテット All is jazz",
      "2025年12月10日(水曜)1926 Guitar Slim 誕生日",
      "JUN 03 TUE Killian 2nd Anniversary",
      "Boris Show",
      "Show: Mono"
    ]

    test_titles.each do |title|
      puts "🔍 Title: #{title}"
      gig_data = { title: title, artists: nil }
      extracted = scraper.send(:extract_band_names, gig_data)
      puts "   ✨ Extracted: #{extracted.join(', ')}"
      puts
    end
  end

  desc "Clean up existing band names using improved extraction"
  task cleanup_names: :environment do
    puts "🧹 CLEANING UP EXISTING BAND NAMES"
    puts "=" * 50

    # Find bands that are likely event descriptions, not real band names
    cleanup_candidates = Band.where(
      "name LIKE '%live%' OR name LIKE '%show%' OR name LIKE '%event%' OR " +
      "name LIKE '%2025%' OR name LIKE '%2024%' OR name LIKE '%2026%' OR " +
      "name LIKE '%●%' OR name LIKE '%DJ：%' OR name LIKE '%anniversary%' OR " +
      "name LIKE '%birthday%' OR name LIKE '%release%' OR name LIKE '%tour%' OR " +
      "name LIKE '%festival%' OR name LIKE '%party%' OR name LIKE '%session%' OR " +
      "name LIKE '%open %' OR name LIKE '%start %' OR name LIKE '%door %' OR " +
      "name LIKE '%ticket%' OR name LIKE '%price%' OR name LIKE '%¥%'"
    )

    puts "📊 Found #{cleanup_candidates.count} bands that need cleanup..."

    scraper = UnifiedVenueScraper.new
    cleaned_count = 0
    deleted_count = 0

    cleanup_candidates.find_each do |band|
      begin
        # Test if this looks like a real artist name
        if scraper.send(:looks_like_artist_name?, band.name)
          # Try to clean the name
          cleaned_name = scraper.send(:clean_artist_name, band.name)

          if cleaned_name.present? && cleaned_name != band.name && cleaned_name.length > 2
            puts "🧹 Cleaning: #{band.name} → #{cleaned_name}"
            band.update!(name: cleaned_name)
            cleaned_count += 1
          end
        else
          # This doesn't look like a real artist - check if we should delete it
          if should_delete_band?(band)
            puts "🗑️  Deleting: #{band.name} (obvious event description)"
            band.destroy
            deleted_count += 1
          end
        end
      rescue => e
        puts "⚠️ Error processing #{band.name}: #{e.message}"
      end
    end

    puts ""
    puts "🎉 CLEANUP COMPLETE!"
    puts "📊 Cleaned #{cleaned_count} band names"
    puts "📊 Deleted #{deleted_count} obvious event descriptions"

    puts ""
    puts "🎼 UPDATED GENRE DISTRIBUTION:"
    Band.group(:genre).order(Arel.sql('COUNT(*) DESC')).count.each_with_index do |(genre, count), index|
      percentage = (count.to_f / Band.count * 100).round(1)
      puts "  #{index + 1}. #{genre}: #{count} bands (#{percentage}%)"
    end
  end

  desc "Re-extract band names from gig titles using improved system"
  task re_extract_from_gigs: :environment do
    puts "🔄 RE-EXTRACTING BAND NAMES FROM GIG DATA"
    puts "=" * 50

    # Find gigs with bands that look like event descriptions
    problematic_gigs = Gig.joins(:bands)
                         .where(bands: { genre: 'Unknown' })
                         .where("bands.name LIKE '%live%' OR bands.name LIKE '%show%' OR bands.name LIKE '%event%' OR bands.name LIKE '%2025%'")
                         .includes(:bands)
                         .limit(100)

    puts "📊 Found #{problematic_gigs.count} gigs with problematic band associations..."

    scraper = UnifiedVenueScraper.new
    improved_count = 0

    problematic_gigs.each do |gig|
      # We don't have the original scraped data, so we'll work with what we have
      # This is a simplified re-extraction based on existing band names

      current_bands = gig.bands.map(&:name)
      puts "🔍 Gig bands: #{current_bands.join(', ')}"

      # Try to extract better names from the current band names
      improved_names = []
      current_bands.each do |band_name|
        gig_data = { title: band_name, artists: nil }
        extracted = scraper.send(:extract_band_names, gig_data)
        improved_names.concat(extracted)
      end

      # Remove duplicates and filter
      improved_names = improved_names.uniq.reject { |name| name == "Live Performance" }

      if improved_names.any? && improved_names != current_bands
        puts "   ✨ Improved: #{improved_names.join(', ')}"

        # Update the gig's band associations
        gig.bands.clear
        improved_names.each do |band_name|
          band = scraper.send(:find_or_create_band, band_name)
          gig.bands << band if band
        end

        improved_count += 1
      end
    end

    puts ""
    puts "🎉 RE-EXTRACTION COMPLETE!"
    puts "📊 Improved #{improved_count} gigs"
  end

  private

  def should_delete_band?(band)
    name = band.name.downcase

    # Delete if it's obviously an event description
    return true if name.match?(/\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/) # Contains dates
    return true if name.match?(/anniversary|birthday|release tour|festival|party session/i)
    return true if name.match?(/open \d|start \d|door \d/i) # Time info
    return true if name.match?(/ticket|price|admission|¥\d+/i) # Pricing
    return true if name.match?(/^(live|show|event|performance|concert)$/i) # Generic terms
    return true if name.length > 100 # Too long

    # Don't delete if it has bookings (might be legitimate despite odd name)
    return false if band.bookings.any?

    false
  end
end
