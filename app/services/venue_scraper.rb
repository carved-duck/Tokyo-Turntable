class VenueScraper
  require 'open-uri'
  require 'nokogiri'
  require 'json'
  require 'ferrum'
  require 'uri' # Needed for URI.join
  require 'fileutils' # Added for FileUtils.mkdir_p for debug folder

  # Base URL for relative paths like image links
  BASE_URL = "https://www.tokyogigguide.com"

  # Set this constant to true to scrape only the first link,
  # or false to scrape all links.
  SCRAPE_FIRST_LINK_ONLY = true

  def venue_scraper
    filepath = "./db/data/venue_links.json"
    unless File.exist?(filepath)
      puts "ERROR: JSON file not found at #{filepath}. Please ensure you've run the link scraping step first."
      return
    end

    puts "--- Starting venue detail scraping from #{filepath} ---"
    raw_data = File.read(filepath)
    parsed_data = JSON.parse(raw_data)

    venue_links = parsed_data['venue_detail_urls']

    if venue_links.nil? || !venue_links.is_a?(Array) || venue_links.empty?
      puts "ERROR: 'venue_detail_urls' key not found, is not an array, or is empty in JSON file. No links to scrape."
      return
    end

    # --- MODIFICATION: Easily switch between first link and all links ---
    if SCRAPE_FIRST_LINK_ONLY
      links_to_process = venue_links.first(1)
      puts "Processing only the first 1 venue link for debugging (set SCRAPE_FIRST_LINK_ONLY to false to scrape all)."
    else
      links_to_process = venue_links
      puts "Found #{venue_links.count} venue links in JSON to scrape details from."
    end
    # --- END MODIFICATION ---

    all_scraped_venues_data = [] # Initialize an array to store all scraped venue data

    browser = nil # Initialize browser outside the loop
    begin
      browser = Ferrum::Browser.new(
        timeout: 90,
        headless: true # Set to false to watch the browser for debugging
      )

      # Ensure debug directory exists (added this for cleaner debug HTML saving)
      FileUtils.mkdir_p('./tmp/debug_html') unless File.directory?('./tmp/debug_html')

      links_to_process.each_with_index do |venue_link, index|
        puts "\n--- Scaping venue #{index + 1}/#{links_to_process.count}: #{venue_link} ---" # Adjusted count for clarity

        begin
          browser.go_to(venue_link)
          puts "  Navigated to #{venue_link}."

          # It's good practice to wait for content if page loads dynamically
          puts "  Sleeping for 3 seconds to allow initial page render..."
          sleep(3)

          # --- MODIFICATION: Save browser.body to a file for inspection ---
          # This was missing in your "current code" but is crucial for debugging selectors.
          debug_html_filename = "./tmp/debug_html/#{URI.parse(venue_link).host.gsub('.', '_')}_#{URI.parse(venue_link).path.gsub(/\W/, '_')}_#{Time.now.to_i}.html"
          File.open(debug_html_filename, "wb") do |file|
            file.write(browser.body)
          end
          puts "  DEBUG: Saved page HTML to #{debug_html_filename}. Please inspect this file."
          puts "  Compare the selectors in scrape_venue_details with the content of this file to debug."
          # --- END MODIFICATION ---

          page_html_doc = Nokogiri::HTML.parse(browser.body)
          puts "  Successfully fetched and parsed page content via headless browser."

          # Call the dedicated method to scrape details from the current page
          venue_data = scrape_venue_details(page_html_doc, venue_link)

          if venue_data
            all_scraped_venues_data << venue_data
            puts "  Successfully scraped data for: #{venue_data[:name]}."
            # Here you would typically integrate with your Rails models:
            # venue = Venue.find_or_create_by!(name: venue_data[:name]) do |v|
            #   v.website = venue_data[:website]
            #   v.address = venue_data[:address]
            #   v.email = venue_data[:email]
            #   v.neighborhood = venue_data[:neighborhood]
            #   v.details = venue_data[:details]
            #   v.photo = venue_data[:photo]
            # end
            # puts "  Venue '#{venue.name}' (ID: #{venue.id}) #{venue.new_record? ? 'CREATED' : 'UPDATED'}."
          else
            puts "  WARNING: Could not scrape data for #{venue_link}."
          end

        rescue Ferrum::TimeoutError
          puts "  ERROR: Timeout while loading #{venue_link}. Skipping."
        rescue Ferrum::StatusError => e
          puts "  ERROR: HTTP Status error for #{venue_link}: #{e.message}. Skipping."
        rescue Nokogiri::SyntaxError => e
          puts "  ERROR: Malformed HTML on #{venue_link}: #{e.message}. Skipping."
        rescue StandardError => e
          puts "  ERROR: An unexpected error occurred while scraping #{venue_link}: #{e.message}. Skipping."
        end
      end # end each venue_link loop

    ensure
      browser.quit if browser # Ensure the browser is closed
      puts "--- Browser closed. ---"
    end

    # Save all scraped data to a JSON file
    output_filepath = "./db/data/scraped_venues_details.json"
    begin
      File.open(output_filepath, "wb") do |file|
        file.write(JSON.pretty_generate({ venues: all_scraped_venues_data }))
      end
      puts "\n--- Successfully saved all scraped venue details to #{output_filepath} ---"
    rescue StandardError => e
      puts "ERROR: Failed to save scraped data to JSON file: #{e.message}"
    end
  end

  # This method extracts specific details from a single venue detail page HTML
  def scrape_venue_details(html_doc, current_url)
    venue_data = {}

    # 2. name (title - using h1)
    name_element = html_doc.at_css('h1')
    venue_data[:name] = name_element.text.strip if name_element
    venue_data[:name] ||= "Not Available"


    # 3. website (venue a href)
    website_element = html_doc.at_css('dd.jem-website a')
    if website_element
      venue_data[:website] = website_element['href']
    elsif html_doc.at_css('.jem-detail-item:contains("Website") a')
      # Fallback for "Website" text label
      venue_data[:website] = html_doc.at_css('.jem-detail-item:contains("Website") a')['href']
    end
    venue_data[:website] ||= "Not Listed"


    # 4. address (address Japanese - exactly as written, from custom1 class)
    # Target the dd element with class "custom1"
    japanese_address_element = html_doc.at_css('dd.custom1')

    if japanese_address_element
      # Extract the text content directly
      venue_data[:address] = japanese_address_element.text.strip
    else
      venue_data[:address] = "Not Available"
    end
    puts "    Address: #{venue_data[:address]}"


    # 5. email: "not listed" (as per your request, confirm no obvious email element)
    # Based on the provided HTML, there isn't a dedicated email field.
    venue_data[:email] = "Not Listed"


    # 6. neighborhood (venue city - using addressLocality)
    neighborhood_element = html_doc.at_css('dd.jem-address span[itemprop="addressLocality"]')
    venue_data[:neighborhood] = neighborhood_element.text.strip if neighborhood_element
    venue_data[:neighborhood] ||= "Not Available"


    # 7. details (description)
    details_element = html_doc.at_css('div.jem-introtext')
    venue_data[:details] = details_element.text.strip if details_element
    venue_data[:details] ||= "No Description"


    # 8. photo (flyer image link)
    photo_element = html_doc.at_css('div.jem-image img.jem-photo')
    if photo_element && photo_element['src']
      # Construct full URL for relative image paths
      venue_data[:photo] = URI.join(BASE_URL, photo_element['src']).to_s
    end
    venue_data[:photo] ||= "No Photo Available"

    venue_data
  end
end
