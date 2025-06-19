namespace :scraping do
  desc "Clear blacklist for proven venues and fix scraping issues"
  task fix_blacklist: :environment do
    puts '🔧 Fixing blacklist issues for proven venues...'

    blacklist_file = Rails.root.join('tmp', 'venue_blacklist.json')

    # Create a backup first
    if File.exist?(blacklist_file)
      backup_file = Rails.root.join('tmp', 'venue_blacklist_backup.json')
      FileUtils.cp(blacklist_file, backup_file)
      puts "📦 Backed up current blacklist to: #{backup_file}"
    end

    # List of proven venues that should never be blacklisted
    proven_venue_names = ['Antiknock', 'Den-atsu', 'Milkyway', 'Yokohama Arena', '東高円寺二万電圧']

    # Create clean blacklist without proven venues
    clean_blacklist = {
      timeout_venues: [],
      dead_venues: [],
      no_content_venues: [],
      successful_venues: []
    }

    File.write(blacklist_file, JSON.pretty_generate(clean_blacklist))
    puts "✅ Cleared blacklist - proven venues are no longer blacklisted"

    puts "\n🎯 Proven venues that are now available for scraping:"
    proven_venue_names.each { |name| puts "  ✓ #{name}" }

    puts "\n💡 Next steps:"
    puts "  1. Test proven venues: rails unified_scraper:test_proven_venues"
    puts "  2. Run a small scraping test to verify everything works"
  end
end
