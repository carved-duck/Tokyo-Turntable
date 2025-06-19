namespace :unified_scraper do
  desc "Test our 5 proven venues with unified Selenium scraper"
  task test_proven_venues: :environment do
    puts "🧪 Starting Proven Venues Test..."

    scraper = UnifiedVenueScraper.new
    result = scraper.test_proven_venues

    puts "\n🎯 TEST SUMMARY:"
    puts "Successful venues: #{result[:successful_venues]}/5"
    puts "Total gigs found: #{result[:total_gigs]}"
    puts "Failed venues: #{result[:failed_venues].count}"

    if result[:successful_venues] == 5
      puts "\n🎉 ALL PROVEN VENUES WORKING! Ready for N+1 scaling."
    else
      puts "\n⚠️  Some proven venues failed. Fix these before scaling:"
      result[:failed_venues].each { |failure| puts "  • #{failure[:venue]} - #{failure[:reason]}" }
    end
  end

  desc "Run limited N+1 venue scaling test (default: 15 venues)"
  task :limited_n_plus_one, [:limit] => :environment do |t, args|
    limit = args[:limit]&.to_i || 15

    puts "🚀 Starting Limited N+1 Test with #{limit} candidate venues..."

    scraper = UnifiedVenueScraper.new
    result = scraper.limited_n_plus_one_test(limit)

    puts "\n🎯 N+1 TEST SUMMARY:"
    puts "Total successful venues: #{result[:total_successful_venues]}"
    puts "Total gigs found: #{result[:total_gigs]}"
    puts "New venues added: #{result[:new_venues_added]}"
    puts "Venues deleted (dead): #{result[:deleted_venues]}"

    if result[:new_venues_added] > 0
      puts "\n🎉 Successfully scaled! Added #{result[:new_venues_added]} new working venues."
    else
      puts "\n⚠️  No new venues found. May need to adjust filtering criteria."
    end
  end

  desc "Quick website accessibility check for candidate venues"
  task :check_websites, [:limit] => :environment do |t, args|
    limit = args[:limit]&.to_i || 20

    puts "🔍 Checking website accessibility for #{limit} candidate venues..."

    scraper = UnifiedVenueScraper.new
    venues = scraper.send(:get_candidate_venues, limit)

    accessible_count = 0
    dead_count = 0

    venues.each_with_index do |venue, index|
      print "#{index + 1}/#{venues.count}: #{venue.name}... "

      if scraper.send(:website_accessible?, venue.website)
        puts "✅ ACCESSIBLE"
        accessible_count += 1
      else
        puts "❌ DEAD"
        dead_count += 1
      end

      sleep(1) # Rate limiting
    end

    puts "\n📊 ACCESSIBILITY SUMMARY:"
    puts "Accessible: #{accessible_count}/#{venues.count}"
    puts "Dead: #{dead_count}/#{venues.count}"
    puts "Success rate: #{(accessible_count.to_f / venues.count * 100).round(1)}%"
  end
end
