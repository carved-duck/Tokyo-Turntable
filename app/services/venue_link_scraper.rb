class VenueLinkScraper
  require 'open-uri'
  require 'nokogiri'
  require 'json'
  require 'ferrum'
  require 'uri'
  require 'fileutils' # Ensure FileUtils is required for mkdir_p

  BASE_URL = "https://www.tokyogigguide.com"
  # Base URL for the live houses list, without pagination parameter
  LIVE_HOUSES_BASE_LIST_URL = "#{BASE_URL}/en/livehouses"

  def scrape_tokyo_venues_list_links
    puts "--- Starting to scrape live house list links across all pages (using Ferrum) ---"

    # Initialize an array to hold all unique venue links found across all pages
    all_venue_links = []

    browser = nil # Initialize browser outside the loop
    begin
      browser = Ferrum::Browser.new(
        timeout: 90,
        headless: true # Set to false to watch the browser for debugging
      )

      # Loop through the 'start' parameters for pagination
      # From 0 to 950, incrementing by 50
      (0..950).step(50).each do |start_param|
        page_url = "#{LIVE_HOUSES_BASE_LIST_URL}?start=#{start_param}"
        puts "\n--- Navigating to page: #{page_url} ---"

        begin
          browser.go_to(page_url)
          puts "  Navigated to #{page_url}."

          puts "  Sleeping for 5 seconds to allow initial page render..."
          sleep(5) # Give time for content to load

          page_html_doc = Nokogiri::HTML.parse(browser.body)
          puts "  Successfully fetched and parsed page content via headless browser."

          # Optional: Save debug HTML for each page if needed
          # debug_filepath = Rails.root.join("tmp", "debug_venue_list_page_#{start_param}.html")
          # FileUtils.mkdir_p(File.dirname(debug_filepath)) unless File.directory?(File.dirname(debug_filepath))
          # File.open(debug_filepath, "w") { |f| f.write(browser.body) }
          # puts "  Saved current browser HTML to: #{debug_filepath} for inspection."

          list_items = page_html_doc.css('ul.eventlist li.jem-event.jem-list-row.jem-small-list')

          if list_items.empty?
            puts "  WARNING: No 'ul.eventlist li.jem-event.jem-list-row.jem-small-list' elements found on #{page_url}."
            puts "  This might indicate the end of valid pages or a selector issue on this page."
            # Depending on the site, you might break here if you're sure there are no more pages
            # For now, we'll continue to the next `start_param` in case it's an intermittent issue.
            next
          end

          puts "  Found #{list_items.count} list items on this page."

          # Extract links from the current page and add to the master list
          list_items.each do |venue_card|
            link_element = venue_card.at_css('.jem-event-info-small.jem-event-venue a')
            if link_element && link_element['href']
              relative_path = link_element['href']
              full_url = URI.join(BASE_URL, relative_path).to_s
              all_venue_links << full_url
            else
              puts "  WARNING: Could not find a valid link element within a venue card on #{page_url}."
            end
          end

        rescue Ferrum::TimeoutError => e
          puts "  ERROR: Timeout while loading #{page_url}: #{e.message}. Skipping this page."
        rescue Ferrum::StatusError => e
          puts "  ERROR: HTTP Status error for #{page_url}: #{e.message}. Skipping this page."
        rescue Nokogiri::SyntaxError => e
          puts "  ERROR: Malformed HTML on #{page_url}: #{e.message}. Skipping this page."
        rescue StandardError => e
          puts "  ERROR: An unexpected error occurred while scraping #{page_url}: #{e.message}. Skipping this page."
          puts e.backtrace.join("\n")
        end
      end # End of pagination loop

      puts "\n--- Finished scraping live house list links across all pages ---"
      puts "Total unique venue links found: #{all_venue_links.uniq.count}"

      # Save all unique links to the JSON file
      filepath = Rails.root.join("db", "data", "venue_links.json")
      FileUtils.mkdir_p(File.dirname(filepath)) unless File.directory?(File.dirname(filepath))
      File.open(filepath, "wb") do |file|
        file.write(JSON.pretty_generate({ venue_detail_urls: all_venue_links.uniq }))
      end
      puts "Saved all unique venue links to: #{filepath}"

      return all_venue_links.uniq # Return the unique list of links
    rescue StandardError => e
      puts "ERROR: An unexpected error occurred during the overall scrape process: #{e.message}"
      puts e.backtrace.join("\n")
      return [] # Return empty array on overall failure
    ensure
      browser.quit if browser # Ensure the browser is closed
      puts "--- Browser closed. ---"
    end
  end
end
