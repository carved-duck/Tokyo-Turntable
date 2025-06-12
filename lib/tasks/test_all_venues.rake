namespace :venues do
  desc "Test all venues in database"
  task test_all: :environment do
    puts '🚀 TESTING ALL VENUES IN DATABASE'

    scraper = UnifiedVenueScraper.new(verbose: true)
    start_time = Time.current

    all_venues = Venue.where.not(website: [nil, ''])
    puts "Found #{all_venues.count} venues with websites"

    # Test proven venues first
    proven_result = scraper.test_proven_venues
    puts "Proven venues: #{proven_result[:successful_venues]} successful, #{proven_result[:total_gigs]} gigs"

    # Test all remaining venues
    remaining_venues = all_venues.where.not(name: ['Antiknock', '20000 Den-atsu (二万電圧)', 'Milkyway', 'Yokohama Arena'])
    puts "Testing #{remaining_venues.count} remaining venues..."

    successful_venues = proven_result[:successful_venues]
    total_gigs = proven_result[:total_gigs]
    failed_venues = []

    remaining_venues.find_each.with_index do |venue, index|
      puts "\n[#{index + 1}/#{remaining_venues.count}] Testing: #{venue.name}"

      begin
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }

        gigs = scraper.send(:scrape_venue_optimized, venue_config)
        valid_gigs = scraper.send(:filter_valid_gigs, gigs)

        if valid_gigs.any?
          puts "✅ SUCCESS: #{valid_gigs.count} gigs"
          scraper.send(:save_gigs_to_database, valid_gigs, venue.name)
          successful_venues += 1
          total_gigs += valid_gigs.count
        else
          puts "❌ NO GIGS"
          failed_venues << venue.name
        end
      rescue => e
        puts "❌ ERROR: #{e.message}"
        failed_venues << venue.name
      end
    end

    duration = Time.current - start_time
    puts "\n🏁 FULL DATABASE TEST COMPLETE!"
    puts "⚡ Total time: #{duration.round(2)} seconds"
    puts "🏆 Successful venues: #{successful_venues}/#{all_venues.count}"
    puts "📊 Total gigs found: #{total_gigs}"
    puts "❌ Failed venues: #{failed_venues.count}"
  end

  desc "Test venues with improved filters - focus on previously failing ones"
  task test_improved_filters: :environment do
    puts '🧪 TESTING IMPROVED FILTERS ON PROBLEMATIC VENUES'
    puts '=================================================='

    # Target venues that were finding gigs but losing them to filtering
    problematic_venues = [
      'CATFISH Tokyo',           # Found 67 gigs → 0 (No date: 67)
      'Zu Bar',                  # Found 20 gigs → 0 (No date: 18, Past date: 1, No title: 1)
      '翠月 (MITSUKI)',          # Found 1 gigs → 0 (No date: 1)
      '虎子食堂 (Toranoko Shokudo)', # Found 1 gigs → 0 (No date: 1)
      'ムンド不二 (Mundo Fuji)',   # Found 1 gigs → 0 (No date: 1)
      'げによい (GENIYOI)',       # Found 1 gigs → 0 (No date: 1)
      '路地と人 (rojitohito)'     # Found 8 gigs → 0 (Past date: 8)
    ]

    scraper = UnifiedVenueScraper.new(verbose: true)
    start_time = Time.current

    successful_venues = 0
    total_gigs = 0
    improved_venues = []
    still_failing = []

    problematic_venues.each_with_index do |venue_name, index|
      venue = Venue.find_by(name: venue_name)

      unless venue
        puts "\n[#{index + 1}/#{problematic_venues.count}] ❌ VENUE NOT FOUND: #{venue_name}"
        still_failing << { venue: venue_name, reason: "Venue not found in database" }
        next
      end

      puts "\n[#{index + 1}/#{problematic_venues.count}] 🔬 Testing: #{venue.name}"
      puts "  URL: #{venue.website}"
      puts "  Previous issue: Found gigs but lost to filtering"

      begin
        venue_config = {
          name: venue.name,
          url: venue.website,
          selectors: scraper.send(:get_general_selectors)
        }

        puts "  🚀 Scraping with improved filters..."
        gigs = scraper.send(:scrape_venue_optimized, venue_config)

        if gigs.any?
          puts "  📊 Raw extraction: Found #{gigs.count} potential gigs"

          # Show some raw gig examples for debugging
          puts "  🔍 Sample raw gigs:"
          gigs.first(3).each_with_index do |gig, i|
            puts "    #{i+1}. Title: '#{gig[:title]}' | Date: '#{gig[:date]}' | Artists: '#{gig[:artists]}'"
          end

          valid_gigs = scraper.send(:filter_valid_gigs, gigs)

          if valid_gigs.any?
            puts "  ✅ SUCCESS: #{valid_gigs.count} valid gigs after improved filtering!"

            # Show valid gigs
            puts "  📅 Valid gigs found:"
            valid_gigs.each do |gig|
              puts "    ✓ #{gig[:date]} - #{gig[:title]}"
            end

            scraper.send(:save_gigs_to_database, valid_gigs, venue.name)
            successful_venues += 1
            total_gigs += valid_gigs.count
            improved_venues << { venue: venue.name, gigs: valid_gigs.count, improvement: "Fixed filtering" }
          else
            puts "  ⚠️  STILL FAILING: Found #{gigs.count} gigs but none passed improved filtering"
            still_failing << { venue: venue.name, reason: "Improved filtering still rejected all gigs" }
          end
        else
          puts "  ❌ NO GIGS: No gigs found during scraping"
          still_failing << { venue: venue.name, reason: "No gigs found during scraping" }
        end

      rescue => e
        puts "  ❌ ERROR: #{e.message}"
        still_failing << { venue: venue.name, reason: e.message }
      end

      # Brief pause between venues
      sleep(2) unless index == problematic_venues.count - 1
    end

    duration = Time.current - start_time
    puts "\n🏁 IMPROVED FILTERS TEST COMPLETE!"
    puts "="*50
    puts "⚡ Total time: #{duration.round(2)} seconds"
    puts "🎯 Venues tested: #{problematic_venues.count}"
    puts "✅ Successful venues: #{successful_venues}"
    puts "📊 Total gigs found: #{total_gigs}"
    puts "❌ Still failing: #{still_failing.count}"

    if improved_venues.any?
      puts "\n🎉 IMPROVEMENTS ACHIEVED:"
      improved_venues.each do |improvement|
        puts "  • #{improvement[:venue]}: #{improvement[:gigs]} gigs (#{improvement[:improvement]})"
      end
    end

    if still_failing.any?
      puts "\n⚠️  STILL NEED WORK:"
      still_failing.each_with_index do |failure, i|
        puts "  #{i+1}. #{failure[:venue]} - #{failure[:reason]}"
      end
    end

    # Save results
    results = {
      tested_venues: problematic_venues,
      successful_venues: successful_venues,
      total_gigs: total_gigs,
      improvements: improved_venues,
      failures: still_failing,
      test_duration: duration.round(2)
    }

    output_file = Rails.root.join('db', 'data', 'improved_filters_test.json')
    File.write(output_file, JSON.pretty_generate(results))
    puts "\n📁 Results saved to: #{output_file}"
  end

  desc "Clean up problematic venues - delete or mark social media only venues"
  task cleanup_problematic: :environment do
    puts '🧹 CLEANING UP PROBLEMATIC VENUES'
    puts '================================'

    # Venues that should be deleted (weird/invalid websites)
    venues_to_delete = [
      '路地と人 (rojitohito)' # User confirmed this should be deleted
    ]

    # Venues that are social media only (should be marked for skipping)
    social_media_venues = [
      'ムンド不二 (Mundo Fuji)',  # LinkTree page
      'げによい (GENIYOI)'        # Instagram only
    ]

    # Image-based schedule venues (mark as special handling)
    image_schedule_venues = [
      '翠月 (MITSUKI)' # Uses images for schedule information
    ]

    deleted_count = 0
    updated_count = 0
    not_found_count = 0

    puts "\n🗑️  DELETING INVALID VENUES:"
    venues_to_delete.each do |venue_name|
      venue = Venue.find_by(name: venue_name)
      if venue
        begin
          # Check if venue has gigs
          gig_count = venue.gigs.count
          if gig_count > 0
            puts "  ⚠️  #{venue_name} has #{gig_count} gigs - updating website to NULL instead of deleting"
            venue.update!(website: nil)
            updated_count += 1
          else
            puts "  🗑️  Deleting: #{venue_name}"
            venue.destroy!
            deleted_count += 1
          end
        rescue => e
          puts "  ❌ Error with #{venue_name}: #{e.message}"
        end
      else
        puts "  ❌ Not found: #{venue_name}"
        not_found_count += 1
      end
    end

    puts "\n📱 MARKING SOCIAL MEDIA ONLY VENUES:"
    social_media_venues.each do |venue_name|
      venue = Venue.find_by(name: venue_name)
      if venue
        begin
          # Add a note to description indicating it's social media only
          current_description = venue.description || ""
          unless current_description.include?("SOCIAL_MEDIA_ONLY")
            new_description = "#{current_description}\n\n[SOCIAL_MEDIA_ONLY - Skip automated scraping]".strip
            venue.update!(description: new_description)
            puts "  📱 Marked as social media only: #{venue_name}"
            updated_count += 1
          else
            puts "  ✅ Already marked: #{venue_name}"
          end
        rescue => e
          puts "  ❌ Error with #{venue_name}: #{e.message}"
        end
      else
        puts "  ❌ Not found: #{venue_name}"
        not_found_count += 1
      end
    end

    puts "\n🖼️  MARKING IMAGE-BASED SCHEDULE VENUES:"
    image_schedule_venues.each do |venue_name|
      venue = Venue.find_by(name: venue_name)
      if venue
        begin
          # Add a note to description indicating it uses image-based schedules
          current_description = venue.description || ""
          unless current_description.include?("IMAGE_BASED_SCHEDULE")
            new_description = "#{current_description}\n\n[IMAGE_BASED_SCHEDULE - Schedule information in images, requires manual review]".strip
            venue.update!(description: new_description)
            puts "  🖼️  Marked as image-based schedule: #{venue_name}"
            updated_count += 1
          else
            puts "  ✅ Already marked: #{venue_name}"
          end
        rescue => e
          puts "  ❌ Error with #{venue_name}: #{e.message}"
        end
      else
        puts "  ❌ Not found: #{venue_name}"
        not_found_count += 1
      end
    end

    puts "\n🏁 CLEANUP COMPLETE!"
    puts "="*30
    puts "🗑️  Deleted venues: #{deleted_count}"
    puts "📝 Updated venues: #{updated_count}"
    puts "❌ Not found: #{not_found_count}"

    puts "\n💡 These venues will now be properly handled by the improved scraper:"
    puts "  • Social media only venues will be automatically skipped"
    puts "  • Image-based schedule venues will show helpful messages for manual review"
    puts "  • Invalid venues have been removed from the database"
  end
end
