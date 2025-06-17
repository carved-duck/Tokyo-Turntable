namespace :venues do
  desc "Scrape events from all venues"
  task scrape: :environment do
    venues = [
      {
        name: 'Den-Atsu',
        website: 'https://den-atsu.com'
      },
      {
        name: 'Antiknock',
        website: 'https://antiknock.net'
      },
      {
        name: 'Shibuya Milkyway',
        website: 'https://www.shibuyamilkyway.com'
      },
      {
        name: 'Yokohama Arena',
        website: 'https://www.yokohama-arena.co.jp'
      }
    ]


    venues.each do |venue|
      puts "\nScraping #{venue[:name]}..."

      # First get all event pages
      navigator = VenueNavigator.new(venue)
      event_pages = navigator.find_event_pages

      puts "Found #{event_pages.size} event pages"

      # Then scrape each page
      event_pages.each do |page_url|
        puts "Scraping page: #{page_url}"
        scraper = VenueWebsiteScraper.new(page_url, venue[:name])
        events = scraper.scrape

        puts "Found #{events.size} events on this page"
        events.each do |event|
          puts "  - #{event[:date]} #{event[:time]}: #{event[:title]}"
          puts "    Price: #{event[:price]}"
          puts "    Ticket: #{event[:ticket_link]}" if event[:ticket_link]
        end
      end
    end
  end
end
