class LightningFastScraper
  def initialize(options = {})
    @verbose = options[:verbose] || false
    @max_parallel = options[:max_parallel] || 10  # Higher parallelism
    @timeout = 3  # Much shorter timeout
    @scraped_count = 0
    @successful_count = 0
    @start_time = Time.current
  end

  # 🚀 LIGHTNING FAST SCRAPING - SPEED OVER EVERYTHING
  def scrape_all_venues_lightning_fast
    puts "⚡ LIGHTNING FAST SCRAPER - MAXIMUM SPEED MODE" if @verbose
    puts "🎯 Target: Under 10 minutes for all venues" if @verbose
    puts "⚡ Strategy: HTTP-first, minimal timeouts, aggressive parallelism" if @verbose
    puts "=" * 60 if @verbose

    # Get all venues, prioritize simple ones first
    venues = Venue.where.not(website: [nil, ''])
                  .where.not("website ILIKE '%facebook%'")
                  .where.not("website ILIKE '%instagram%'")
                  .where.not("website ILIKE '%twitter%'")
                  .order(:id)  # Simple ordering for speed

    puts "📊 Processing #{venues.count} venues with LIGHTNING speed..." if @verbose

    # Process in large batches with high parallelism
    total_gigs = 0
    total_successful = 0
    batch_size = 50  # Larger batches

    venues.find_in_batches(batch_size: batch_size) do |venue_batch|
      batch_start = Time.current
      batch_results = process_lightning_batch(venue_batch)

      total_successful += batch_results[:successful]
      total_gigs += batch_results[:gigs]

      batch_duration = Time.current - batch_start
      puts "⚡ Batch: #{batch_results[:successful]}/#{venue_batch.count} (#{batch_duration.round(1)}s)" if @verbose
    end

    total_duration = Time.current - @start_time
    puts "\n⚡ LIGHTNING SCRAPE COMPLETE!" if @verbose
    puts "📊 #{total_successful}/#{venues.count} successful (#{(total_successful.to_f/venues.count*100).round(1)}%)" if @verbose
    puts "⏱️  Total time: #{(total_duration/60).round(1)} minutes" if @verbose
    puts "🚀 Speed: #{(venues.count.to_f/total_duration).round(1)} venues/second" if @verbose

    { successful: total_successful, total_gigs: total_gigs, duration: total_duration }
  end

  private

  def process_lightning_batch(venues)
    successful = 0
    total_gigs = 0

    # Use thread pool for maximum parallelism
    executor = Concurrent::ThreadPoolExecutor.new(
      min_threads: 1,
      max_threads: @max_parallel,
      max_queue: 0,
      fallback_policy: :caller_runs
    )

    futures = venues.map do |venue|
      Concurrent::Future.execute(executor: executor) do
        scrape_venue_lightning_fast(venue)
      end
    end

    # Collect results with short timeout
    futures.each do |future|
      begin
        result = future.value(10)  # 10 second max wait per venue
        if result[:success]
          successful += 1
          total_gigs += result[:gigs]
        end
      rescue Concurrent::TimeoutError
        # Skip timeouts - speed is priority
      end
    end

    executor.shutdown
    executor.wait_for_termination(5) || executor.kill

    { successful: successful, gigs: total_gigs }
  end

  def scrape_venue_lightning_fast(venue)
    return { success: false, gigs: 0 } unless venue.website.present?

    begin
      # ONLY try HTTP - no browser fallback for speed
      gigs = scrape_http_only(venue)

      if gigs&.any?
        valid_gigs = filter_gigs_fast(gigs)
        if valid_gigs.any?
          # Save to database quickly
          save_gigs_fast(valid_gigs, venue.name)
          return { success: true, gigs: valid_gigs.count }
        end
      end

      { success: false, gigs: 0 }
    rescue => e
      { success: false, gigs: 0 }
    end
  end

  def scrape_http_only(venue)
    uri = URI(venue.website)

    # Ultra-fast HTTP client
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 2   # Very short
    http.read_timeout = 3   # Very short

    request = Net::HTTP::Get.new(uri.path.present? ? uri.path : '/')
    request['User-Agent'] = 'Mozilla/5.0 (compatible; TokyoTurntable/1.0)'

    response = http.request(request)

    if response.code == '200'
      doc = Nokogiri::HTML(response.body)
      extract_gigs_fast(doc, venue)
    else
      []
    end
  rescue => e
    []
  end

  def extract_gigs_fast(doc, venue)
    gigs = []

    # Super simple extraction - just look for common patterns
    doc.css('div, article, section, li').each do |element|
      text = element.text.strip
      next if text.length < 10

      # Look for date patterns
      if text.match(/\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/) ||
         text.match(/\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{4}/) ||
         text.match(/\d{1,2}月\d{1,2}日/)

        gigs << {
          title: text[0..100],  # First 100 chars
          date: extract_date_fast(text),
          venue_name: venue.name,
          source_url: venue.website
        }
      end

      break if gigs.count >= 20  # Limit for speed
    end

    gigs
  end

  def extract_date_fast(text)
    # Very simple date extraction
    if match = text.match(/(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})/)
      "#{match[1]}-#{match[2].rjust(2, '0')}-#{match[3].rjust(2, '0')}"
    elsif match = text.match(/(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})/)
      "#{match[3]}-#{match[2].rjust(2, '0')}-#{match[1].rjust(2, '0')}"
    elsif match = text.match(/(\d{1,2})月(\d{1,2})日/)
      "2025-#{match[1].rjust(2, '0')}-#{match[2].rjust(2, '0')}"
    else
      Date.current.to_s
    end
  rescue
    Date.current.to_s
  end

  def filter_gigs_fast(gigs)
    # Minimal filtering for speed
    gigs.select do |gig|
      gig[:title].present? &&
      gig[:date].present? &&
      gig[:title].length > 5
    end
  end

  def save_gigs_fast(gigs, venue_name)
    # Batch insert for speed
    venue = Venue.find_by(name: venue_name)
    return unless venue

    gigs.each do |gig_data|
      begin
        Gig.create!(
          title: gig_data[:title],
          date: Date.parse(gig_data[:date]),
          venue: venue,
          user: User.first
        )
      rescue => e
        # Skip errors for speed
      end
    end
  rescue => e
    # Skip all errors for speed
  end
end
