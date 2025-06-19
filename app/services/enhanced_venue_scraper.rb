class EnhancedVenueScraper < BaseScraper
  BASE_URL = "https://www.tokyogigguide.com"
  REQUIRED_FIELDS = ['name', 'address', 'neighborhood']

  def scrape_venues
    @logger.info("Starting enhanced venue scraping process")

    # Load existing data if available
    existing_data = load_from_json('scraped_venues_details.json')
    existing_venues = existing_data&.dig('venues') || []

    # Get venue links
    venue_links = get_venue_links
    @logger.info("Found #{venue_links.count} venue links to process")

    # Process venues in parallel
    new_venues = parallel_process(venue_links) do |venue_link|
      scrape_venue_details(venue_link)
    end.compact

    # Merge with existing data
    merged_venues = merge_data(existing_venues, new_venues, 'name')

    # Save results
    save_to_json({ venues: merged_venues }, 'scraped_venues_details.json')

    @logger.info("Completed venue scraping process. Total venues: #{merged_venues.count}")
    merged_venues
  end

  private

  def get_venue_links
    links = []

    with_browser do |browser|
      (0..950).step(50) do |start_param|
        page_url = "#{BASE_URL}/en/livehouses?start=#{start_param}"
        @logger.info("Processing page: #{page_url}")

        with_retry do
          browser.get(page_url)
          rate_limit

          page_html_doc = Nokogiri::HTML.parse(browser.page_source)
          list_items = page_html_doc.css('ul.eventlist li.jem-event.jem-list-row.jem-small-list')

          break if list_items.empty?

          list_items.each do |venue_card|
            link_element = venue_card.at_css('.jem-event-info-small.jem-event-venue a')
            if link_element && link_element['href']
              full_url = URI.join(BASE_URL, link_element['href']).to_s
              links << full_url
            end
          end
        end
      end
    end

    links.uniq
  end

  def scrape_venue_details(venue_url)
    @logger.info("Scraping venue details from: #{venue_url}")

    with_browser do |browser|
      with_retry do
                  browser.get(venue_url)
        rate_limit

                  page_html_doc = Nokogiri::HTML.parse(browser.page_source)
        venue_data = extract_venue_data(page_html_doc, venue_url)

        # Validate required fields
        validate_required_fields(venue_data, REQUIRED_FIELDS)

        # Geocode address
        if venue_data['address'] && venue_data['address'] != "Not Available"
          geocoded = geocode_address(venue_data['address'])
          venue_data.merge!(geocoded) if geocoded
        end

        venue_data
      end
    end
  rescue => e
    @logger.error("Failed to scrape venue #{venue_url}: #{e.message}")
    nil
  end

  def extract_venue_data(html_doc, url)
    {
      'name' => clean_text(html_doc.at_css('h1')&.text),
      'website' => extract_website(html_doc),
      'address' => clean_text(html_doc.at_css('dd.custom1')&.text),
      'email' => "Not Listed",
      'neighborhood' => clean_text(html_doc.at_css('dd.venue_city[itemprop="addressLocality"]')&.text),
      'details' => clean_text(html_doc.at_css('div.jem-introtext')&.text) || "No Description",
      'photo' => extract_photo(html_doc),
      'source_url' => url,
      'last_updated' => Time.current.iso8601
    }
  end

  def extract_website(html_doc)
    website_element = html_doc.at_css('dd.venue a')
    return "Not Listed" unless website_element && website_element['href']
    clean_text(website_element['href'])
  end

  def extract_photo(html_doc)
    photo_element = html_doc.at_css('a.flyermodal.flyerimage img')
    return "No Photo Available" unless photo_element && photo_element['src']
    clean_text(photo_element['src'])
  end
end
