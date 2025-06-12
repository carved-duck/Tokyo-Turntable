require 'nokogiri'
require 'json'
# require 'ferrum' # Replaced with Selenium WebDriver
require 'uri'
require 'fileutils'
require 'logger'
require 'retryable'
require 'geocoder'
require 'parallel'
require 'selenium-webdriver'

class BaseScraper
  class ScraperError < StandardError; end

  # Configuration
  RETRY_ATTEMPTS = 3
  RETRY_DELAY = 2
  RATE_LIMIT_DELAY = 1
  MAX_PARALLEL_PROCESSES = 4

  def initialize
    @logger = Rails.logger
    setup_geocoder
  end

  private

  def setup_geocoder
    if ENV['MAPBOX_ACCESS_TOKEN'].present?
      Geocoder.configure(
        timeout: 15,
        lookup: :mapbox,
        api_key: ENV['MAPBOX_ACCESS_TOKEN'],
        units: :km
      )
    else
      @logger.warn("No Mapbox access token found. Geocoding will be disabled.")
    end
  end

  def with_browser
    browser = nil
    begin
      browser = create_browser
      yield browser
    ensure
      browser&.quit
    end
  end

  def create_browser
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')

    browser = Selenium::WebDriver.for :chrome, options: options
    browser.manage.timeouts.implicit_wait = 10
    browser.manage.timeouts.page_load = 30
    browser
  end

  def with_retry(max_attempts: 3, delay: 5)
    attempts = 0
    begin
      attempts += 1
      yield
    rescue => e
      if attempts < max_attempts
        @logger.warn("Attempt #{attempts} failed: #{e.message}. Retrying in #{delay} seconds...")
        sleep delay
        retry
      else
        @logger.error("All #{max_attempts} attempts failed: #{e.message}")
        raise
      end
    end
  end

  def wait_for_element(browser, selector, timeout: 10)
    wait = Selenium::WebDriver::Wait.new(timeout: timeout)
    wait.until { browser.find_element(css: selector).displayed? }
  end

  def wait_for_dynamic_content(browser, selector, timeout: 10)
    wait = Selenium::WebDriver::Wait.new(timeout: timeout)
    wait.until do
      element = browser.find_element(css: selector)
      element.displayed? && element.text.present?
    end
  end

  def rate_limit
    sleep(rand(2..4)) # Random delay between 2-4 seconds
  end

  def parallel_process(items, &block)
    Parallel.map(items, in_threads: MAX_PARALLEL_PROCESSES) do |item|
      with_retry do
        block.call(item)
      end
    end
  end

  def clean_text(text)
    return nil if text.nil?
    text.strip.gsub(/\s+/, ' ')
  end

  def validate_required_fields(data, required_fields)
    missing_fields = required_fields.select { |field| data[field].nil? || data[field].empty? }
    if missing_fields.any?
      raise ScraperError, "Missing required fields: #{missing_fields.join(', ')}"
    end
  end

  def geocode_address(address)
    return nil if address.nil? || address == "Not Available"
    return nil unless ENV['MAPBOX_ACCESS_TOKEN'].present?

    begin
      result = Geocoder.search(address).first
      return nil unless result

      {
        latitude: result.latitude,
        longitude: result.longitude,
        formatted_address: result.formatted_address
      }
    rescue => e
      @logger.error("Geocoding failed for address '#{address}': #{e.message}")
      nil
    end
  end

  def save_to_json(data, filename)
    filepath = Rails.root.join('db', 'data', filename)
    FileUtils.mkdir_p(File.dirname(filepath))

    File.open(filepath, 'wb') do |file|
      file.write(JSON.pretty_generate(data))
    end

    @logger.info("Saved data to #{filepath}")
  end

  def load_from_json(filename)
    filepath = Rails.root.join('db', 'data', filename)
    return nil unless File.exist?(filepath)

    JSON.parse(File.read(filepath))
  end

  def merge_data(existing_data, new_data, key_field)
    return new_data if existing_data.nil?

    merged = existing_data.dup
    new_data.each do |item|
      existing_item = merged.find { |e| e[key_field] == item[key_field] }
      if existing_item
        existing_item.merge!(item)
      else
        merged << item
      end
    end

    merged
  end
end

class FourVenuesScraper < BaseScraper
  VENUES = [
    {
      name: "Den-Atsu",
      url: "https://den-atsu.com",
      schedule_path: "/schedule", # might need to adjust
      selectors: {
        events: ".event, .schedule-item, .live",
        title: "h3, .title, .event-title",
        date: ".date, .event-date, time",
        time: ".time, .start-time",
        artists: ".artist, .performer"
      }
    },
    {
      name: "Antiknock",
      url: "https://antiknock.net",
      schedule_path: "/schedule",
      selectors: {
        events: ".event, .schedule-item, .news-item",
        title: "h3, .title, .event-title",
        date: ".date, .event-date",
        time: ".time",
        artists: ".artist, .band"
      }
    },
    {
      name: "Shibuya Milkyway",
      url: "https://www.shibuyamilkyway.com",
      schedule_path: "/schedule",
      selectors: {
        events: ".event, .schedule-item, .live-info",
        title: "h3, .title, .event-title",
        date: ".date, .event-date",
        time: ".time",
        artists: ".artist, .performer"
      }
    },
    {
      name: "Yokohama Arena",
      url: "https://www.yokohama-arena.co.jp",
      schedule_path: "/event",
      selectors: {
        events: ".event, .schedule-item, .event-list-item",
        title: "h3, .title, .event-title",
        date: ".date, .event-date",
        time: ".time",
        artists: ".artist, .performer"
      }
    }
  ]

  def scrape_four_venues
    @logger.info("Starting scraping of 4 specific venues")

    all_events = []

    VENUES.each do |venue_config|
      @logger.info("Scraping #{venue_config[:name]}")
      venue_events = scrape_venue_with_selenium(venue_config)
      all_events.concat(venue_events)
    end

    # Save results
    save_to_json({
      events: all_events,
      venues_scraped: VENUES.map { |v| v[:name] },
      total_events: all_events.count,
      scraped_at: Time.current.iso8601
    }, 'four_venues_events.json')

    @logger.info("Completed scraping. Total events found: #{all_events.count}")
    all_events
  end

  private

  def scrape_venue_with_selenium(venue_config)
    # Implementation placeholder - this should be overridden in subclasses
    []
  end
end
