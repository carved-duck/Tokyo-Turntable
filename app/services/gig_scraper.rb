class GigScraper
  require 'nokogiri'
  require 'json'
  require 'ferrum' # Required for headless browser automation
  require 'uri'    # Required for URI.join if needed, and parsing URLs
  require 'fileutils' # Required for FileUtils.mkdir_p for debug folder
  require 'date'   # REQUIRED: For DateTime.parse and time arithmetic

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
              # IMPORTANT: Use limit 2 to handle values that might contain colons (e.g., a time in 'Price')
              key, value = info_string.split(': ', 2)

              # Handle date and time specifically
              # The regex expects format like "May 28 (Wed)18.30" from the title attribute
              date_time_match = value.scan(/(\w{3} \d{1,2}) \(\w{3}\)(\d{2}\.\d{2})/).flatten
              if date_time_match.any? # If date and time pattern matches
                gig_data['date'] = date_time_match[0] unless date_time_match[0].nil?

                if date_time_match[1] # Check if the time part was captured
                  gig_data['open_time'] = date_time_match[1].gsub('.', ':')

                  begin
                    dummy_date_str = "2000-01-01"
                    parsed_open_time_str = "#{dummy_date_str} #{gig_data['open_time']}"
                    open_datetime = DateTime.parse(parsed_open_time_str)

                    # Add 30 minutes
                    start_datetime_calculated = open_datetime + (30.to_f / (24 * 60)) # 30 minutes in days

                    # Format back to string "HH:MM" for the model
                    gig_data['start_time'] = start_datetime_calculated.strftime('%H:%M')
                  rescue ArgumentError => e
                    puts "  WARNING: Could not parse or calculate start_time for open_time: #{gig_data['open_time']}. Error: #{e.message}"
                    gig_data['start_time'] = nil # Set to nil if parsing/calculation fails
                  end
                else
                  # If open_time part was not captured by regex, set both to nil or default
                  gig_data['open_time'] = nil
                  gig_data['start_time'] = nil
                end

              else

                processed_key = key.downcase.gsub(/\W+/, '_').chomp('_') # Clean key format
                gig_data[processed_key] = value
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
      end

      puts "\n--- Finished scraping gig list links across all pages ---"
      puts "Total gigs found (before uniqueness filter): #{all_gigs.count}"


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
