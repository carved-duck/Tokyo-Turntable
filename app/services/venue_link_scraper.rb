class VenueLinkScraper
  require 'open-uri'
  require 'nokogiri'
  require 'json'
  require 'ferrum'

# This currently only scrapes first page. will need to modify url =50, etc to do all pages.

  BASE_URL = "https://www.tokyogigguide.com"
  LIVE_HOUSES_LIST_URL = "#{BASE_URL}/en/livehouses"

  def scrape_tokyo_venues_list_links
    puts "--- Starting to scrape live house list links (using Ferrum) ---"

    browser = Ferrum::Browser.new(
      timeout: 90,
      headless: true # Set to false to watch the browser for debugging
    )

    begin
      browser.go_to(LIVE_HOUSES_LIST_URL)
      puts "Navigated to #{LIVE_HOUSES_LIST_URL}."

      puts "Sleeping for 5 seconds to allow initial page render..."
      sleep(5)

      page_html_doc = Nokogiri::HTML.parse(browser.body)
      puts "Successfully fetched and parsed page content via headless browser after wait."

      debug_filepath = Rails.root.join("tmp", "debug_venue_list.html")
      FileUtils.mkdir_p(File.dirname(debug_filepath))
      File.open(debug_filepath, "w") { |f| f.write(browser.body) }
      puts "Saved current browser HTML to: #{debug_filepath} for inspection."

      list_items = page_html_doc.css('ul.eventlist li.jem-event.jem-list-row.jem-small-list')

      if list_items.empty?
        puts "  WARNING: No 'ul.eventlist li.jem-event.jem-list-row.jem-small-list' elements found."
        puts "  This indicates the selector might still be incorrect or the page content isn't fully loaded/rendered."
        return []
      end

      puts "  Found #{list_items.count} list items with the revised selector."

      venue_links = []
      list_items.each do |venue_card|
        # Within each list item, find the anchor tag for the venue link.
        # The link is inside a div with classes `jem-event-info-small` and `jem-event-venue`.
        link_element = venue_card.at_css('.jem-event-info-small.jem-event-venue a')
        if link_element && link_element['href']
          relative_path = link_element['href']
          full_url = URI.join(BASE_URL, relative_path).to_s
          venue_links << full_url
        else
          puts "  WARNING: Could not find a valid link element within a venue card."
        end
      end

      if venue_links.empty?
        puts "  No venue links were extracted even though list items were found. Check internal link selector."
      else
        puts "Found #{venue_links.count} venue links on this page."
      end

      filepath = Rails.root.join("db", "data", "venue_links.json")
      FileUtils.mkdir_p(File.dirname(filepath))
      File.open(filepath, "wb") do |file|
        file.write(JSON.pretty_generate({ venue_detail_urls: venue_links }))
      end
      puts "Saved all venue links to: #{filepath}"

      venue_links
    rescue Ferrum::TimeoutError => e
      puts "ERROR: Browser operation timed out: #{e.message}"
      puts "This often means the page didn't load completely within the timeout, or a specific Ferrum operation took too long."
      nil
    rescue StandardError => e
      puts "ERROR: An unexpected error occurred during scrape: #{e.message}"
      puts e.backtrace.join("\n")
      nil
    ensure
      browser.quit
    end
  end
end
