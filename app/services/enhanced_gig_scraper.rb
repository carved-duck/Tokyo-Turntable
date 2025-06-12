class EnhancedGigScraper < BaseScraper
  BASE_URL = "https://www.tokyogigguide.com"
  GIGS_BASE_LIST_URL = "#{BASE_URL}/en/gigs"
  REQUIRED_FIELDS = ['name', 'date', 'live_house']

  def scrape_gigs
    @logger.info("Starting enhanced gig scraping process")

    # Load existing data if available
    existing_data = load_from_json('gigs.json')
    existing_gigs = existing_data&.dig('data') || []

    # Get all gigs
    new_gigs = scrape_all_gigs

    # Merge with existing data
    merged_gigs = merge_data(existing_gigs, new_gigs, ['name', 'date', 'live_house'])

    # Save results
    save_to_json({ data: merged_gigs }, 'gigs.json')

    @logger.info("Completed gig scraping process. Total gigs: #{merged_gigs.count}")
    merged_gigs
  end

  private

  def scrape_all_gigs
    all_gigs = []

    with_browser do |browser|
      (0..250).step(50) do |start_param|
        page_url = "#{GIGS_BASE_LIST_URL}?start=#{start_param}"
        @logger.info("Processing page: #{page_url}")

        with_retry do
                      browser.get(page_url)
          rate_limit

                      page_html_doc = Nokogiri::HTML.parse(browser.page_source)
          gig_list_items = page_html_doc.search('.eventlist li')

          break if gig_list_items.empty?

          gigs_from_page = extract_gigs_from_page(gig_list_items)
          all_gigs.concat(gigs_from_page)

          @logger.info("Found #{gigs_from_page.count} gigs on page #{start_param}")
        end
      end
    end

    all_gigs
  end

  def extract_gigs_from_page(gig_list_items)
    gig_list_items.map do |gig_card|
      begin
        gig_data = extract_gig_data(gig_card)
        validate_required_fields(gig_data, REQUIRED_FIELDS)
        gig_data
      rescue => e
        @logger.error("Failed to extract gig data: #{e.message}")
        nil
      end
    end.compact
  end

  def extract_gig_data(gig_card)
    gig_data = {
      'name' => clean_text(gig_card.search('.jem-event-details h4').text),
      'source_url' => extract_gig_url(gig_card),
      'last_updated' => Time.current.iso8601
    }

    # Extract info from title attributes
    gig_card.search('.jem-event-info').each do |info_item|
      info_string = info_item.attribute("title")&.value
      next unless info_string

      key, value = info_string.split(': ', 2)
      next unless key && value

      processed_key = key.downcase.gsub(/\W+/, '_').chomp('_')

      if processed_key == 'date' || processed_key == 'time'
        process_date_time(value, gig_data)
      else
        gig_data[processed_key] = clean_text(value)
      end
    end

    gig_data
  end

  def process_date_time(value, gig_data)
    # The regex expects format like "May 28 (Wed)18.30"
    date_time_match = value.scan(/(\w{3} \d{1,2}) \(\w{3}\)(\d{2}\.\d{2})/).flatten

    if date_time_match.any?
      gig_data['date'] = date_time_match[0]

      if date_time_match[1]
        open_time = date_time_match[1].gsub('.', ':')
        gig_data['open_time'] = open_time

        begin
          dummy_date_str = "2000-01-01"
          parsed_open_time_str = "#{dummy_date_str} #{open_time}"
          open_datetime = DateTime.parse(parsed_open_time_str)

          # Add 30 minutes for start time
          start_datetime = open_datetime + (30.to_f / (24 * 60))
          gig_data['start_time'] = start_datetime.strftime('%H:%M')
        rescue ArgumentError => e
          @logger.warn("Could not parse time: #{e.message}")
          gig_data['start_time'] = nil
        end
      end
    end
  end

  def extract_gig_url(gig_card)
    link_element = gig_card.at_css('.jem-event-details h4 a')
    return nil unless link_element && link_element['href']
    URI.join(BASE_URL, link_element['href']).to_s
  end
end
