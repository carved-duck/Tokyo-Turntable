class GigScraper
  require 'nokogiri'
  require 'json'
  require 'ferrum' # Required for headless browser automation
  require 'uri'    # Required for URI.join if needed, and parsing URLs
  require 'fileutils' # Required for FileUtils.mkdir_p for debug folder

  BASE_URL = "https://www.tokyogigguide.com"
  GIGS_BASE_LIST_URL = "#{BASE_URL}/en/gigs" # Base URL for gigs list
  START_PARAM_MIN = 0
  START_PARAM_MAX = 250
  START_PARAM_STEP = 50

  def scrape_tokyo_gigs
    puts "--- Starting to scrape gig list links across all pages (using Ferrum) ---"

    # Initialize an array to hold all unique gigs found across all pages
    all_gigs = []

    browser = nil # Initialize browser outside the loop
    begin
      browser = Ferrum::Browser.new(
        timeout: 90,
        headless: true # Set to false to watch the browser for debugging
      )

      # Loop through the 'start' parameters for pagination
      (START_PARAM_MIN..START_PARAM_MAX).step(START_PARAM_STEP).each do |start_param|
        page_url = "#{GIGS_BASE_LIST_URL}?start=#{start_param}"
        puts "\n--- Navigating to gig page: #{page_url} ---"

        begin
          browser.go_to(page_url)
          puts "  Navigated to #{page_url}."

          puts "  Sleeping for 5 seconds to allow initial page render..."
          sleep(5) # Give time for content to load

          page_html_doc = Nokogiri::HTML.parse(browser.body)
          puts "  Successfully fetched and parsed page content via headless browser."

          # Optional: Save debug HTML for each page if needed
          # debug_filepath = Rails.root.join("tmp", "debug_gig_list_page_#{start_param}.html")
          # FileUtils.mkdir_p(File.dirname(debug_filepath)) unless File.directory?(File.dirname(debug_filepath))
          # File.open(debug_filepath, "w") { |f| f.write(browser.body) }
          # puts "  Saved current browser HTML to: #{debug_filepath} for inspection."

          gig_list_items = page_html_doc.search('.eventlist li')

          if gig_list_items.empty?
            puts "  WARNING: No '.eventlist li' elements found on #{page_url}."
            puts "  This might indicate the end of valid pages or a selector issue on this page. Stopping."
            break # Break the loop if no gigs are found, assuming it's the end of pages
          end

          puts "  Found #{gig_list_items.count} gig items on this page."

          # Extract gigs from the current page and add to the master list
          gig_list_items.each do |gig_card|
            gig_data = {}
            gig_data['name'] = gig_card.search('.jem-event-details h4').text.strip

            # Extract info from title attributes
            gig_card.search('.jem-event-info').each do |info_item|
              info_string = info_item.attribute("title").value
              key, value = info_string.split(': ')

              # Handle date and time specifically
              # The regex expects format like "May 28 (Wed)18.30"
              date_time_match = value.scan(/(\w{3} \d{1,2}) \(\w{3}\)(\d{2}\.\d{2})/).flatten
              if date_time_match.any? # If date and time pattern matches
                gig_data['date'] = date_time_match[0] unless date_time_match[0].nil?
                gig_data['open_time'] = date_time_match[1] unless date_time_match[1].nil?
              else
                # For other key-value pairs (Live House, Area, Price, Category)
                gig_data[key.downcase.gsub(/\W+/, '_')] = value
              end
            end
            all_gigs << gig_data
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

      puts "\n--- Finished scraping gig list links across all pages ---"
      puts "Total gigs found (before uniqueness filter): #{all_gigs.count}"

      # Filter for uniqueness. You might need a more robust uniqueness check
      # if gig 'name' alone isn't unique enough (e.g., combine name, date, venue).
      unique_gigs = all_gigs.uniq { |gig| [gig['name'], gig['date'], gig['live_house']] }
      puts "Total unique gigs found: #{unique_gigs.count}"

      # Save all unique gigs to the JSON file
      filepath = Rails.root.join("db", "data", "gigs.json")
      FileUtils.mkdir_p(File.dirname(filepath)) unless File.directory?(File.dirname(filepath))
      File.open(filepath, "wb") do |file|
        file.write(JSON.pretty_generate({ data: unique_gigs }))
      end
      puts "Saved all unique gigs to: #{filepath}"

      return unique_gigs # Return the unique list of gigs
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

# old scraper below to be deleted after top works.

# class GigScraper
#   #require 'open-uri'
#   require 'nokogiri'
#   require 'json'

#   def scrape_tokyo_venues
#     # Getting gigs just from the first page
#     gigs_url = "https://www.tokyogigguide.com/en/gigs"

#     puts "starting scrape"
#     # page_html_file = URI.parse(gigs_url).read
#     page_html_file = File.open("./db/data/gigRawData1.html").read
#     page_html_doc = Nokogiri::HTML.parse(page_html_file)

#     gigs = page_html_doc.search('.eventlist li').map do |gig_card|
#       gig_data = {}
#       gig_data['name'] = gig_card.search('.jem-event-details h4').text.strip
#       gig_card.search('.jem-event-info').each do |info_item|
#         info_string = info_item.attribute("title").value
#         key, value = info_string.split(': ')
#         date, time = value.scan(/(\w{3} \d{1,2}) \(\w{3}\)(\d{2}\.\d{2})/).flatten
#         if date || time
#           gig_data['open_time'] = time unless time.nil?
#           gig_data['date'] = date unless date.nil?
#         else
#           gig_data[key.downcase.gsub(/\W+/, '_')] = value
#         end
#       end
#       gig_data
#     end
#     puts "saving scrape"

#     old_data = File.open("./db/data/gigs.json")
#     old_gigs = JSON.parse(old_data)["data"] || []

#     gigs += old_gigs

#     # saving to a json file
#     filepath = "./db/data/gigs.json"
#     File.open(filepath, "wb") do |file|
#       file.write(JSON.generate({data: gigs.uniq}))
#     end
#   end
# end
