require 'selenium-webdriver'
require 'nokogiri'
require 'json'
require 'uri'
require 'date'
require 'net/http'
require 'concurrent'
require 'fileutils'

class UnifiedVenueScraper
  PROVEN_VENUES = [
    {
      name: "Antiknock",
      url: "https://antiknock.net",
      complexity: :very_complex,
      strategy: :hybrid_browser,
      selectors: {
        gigs: '.pickup_card, .mv_fx, .news-item, .gig, .schedule-item, article, .post',
        title: '.pickup_ttl, .mv_ttl, h1, h2, h3, .title, .gig-title',
        date: '.pickup_date, .pickup_month, .pickup_day, .date, .gig-date, time, .meta',
        time: '.time, .start-time, .gig-time',
        artists: '.pickup_sub, .mv_opt, .artist, .performer, .lineup, .act'
      }
    },
    {
      name: "20000 Den-atsu (二万電圧)",
      url: "https://den-atsu.com",
      urls: ["https://den-atsu.com", "https://den-atsu.com/schedulelist/", "https://den-atsu.com/schedule/"],
      complexity: :simple_but_protected,
      strategy: :cloudflare_bypass,
      special_handling: :monthly_coverage_with_bypass,
      selectors: {
        gigs: '.pickupbox, .box-list li, .news-item, .gig, .live, article, .post, .schedule-item',
        title: '.work-title, h1, h2, h3, .title, .gig-title, .schedule-title',
        date: '.work-title, .date, .gig-date, time, .meta, .schedule-date',
        time: '.time, .start-time, .gig-time',
        artists: '.artist, .performer, .lineup, .act'
      }
    },
    {
      name: "Milkyway",
      url: "https://www.shibuyamilkyway.com",
      urls: ["https://www.shibuyamilkyway.com", "https://www.shibuyamilkyway.com/new/SCHEDULE/"],
      complexity: :complex_interactive,
      strategy: :enhanced_date_navigation,
      special_handling: :milkyway_enhanced_navigation,
      selectors: {
        gigs: '.gig, .schedule-item, article, .post, div[class*="schedule"], div[class*="event"], div, span, table tr',
        title: 'span, h1, h2, h3, .title, .gig-title, div[class*="title"]',
        date: 'span, .date, .gig-date, time, .meta, div[class*="date"]',
        time: 'span, .time, .start-time, .gig-time, div[class*="time"]',
        artists: 'span, .artist, .performer, .lineup, .act, div[class*="artist"]'
      }
    },
    {
      name: "Yokohama Arena",
      url: "https://www.yokohama-arena.co.jp",
      urls: ["https://www.yokohama-arena.co.jp/event/"],
      complexity: :very_complex,
      strategy: :hybrid_browser,
      special_handling: :enhanced_monthly_coverage,
      selectors: {
        gigs: 'table tr, .event-row, .schedule-item, .gig, article, .post',
        title: 'td:nth-child(2), .event-name, .title, .gig-title, h3, h2',
        date: 'td:nth-child(1), .event-date, .date, .gig-date, time',
        time: 'td:nth-child(4), .start-time, .gig-time, .time',
        artists: '.artist, .performer, .lineup, .act'
      }
    },
    # NEW PROVEN VENUES FOR SCALING
    {
      name: "Shibuya O-East",
      url: "https://shibuya-o.com",
      complexity: :medium,
      strategy: :hybrid_http_first,
      selectors: {
        gigs: '.schedule-item, .event-item, .live-info, article, .post',
        title: 'h3, h2, .title, .event-title',
        date: '.date, .event-date, time',
        time: '.time, .start-time',
        artists: '.artist, .performer, .act'
      }
    },
    {
      name: "Shibuya O-West",
      url: "https://shibuya-o.com/west/",
      complexity: :medium,
      strategy: :hybrid_http_first,
      selectors: {
        gigs: '.schedule-item, .event-item, .live-info, article, .post',
        title: 'h3, h2, .title, .event-title',
        date: '.date, .event-date, time',
        time: '.time, .start-time',
        artists: '.artist, .performer, .act'
      }
    },
    {
      name: "Liquid Room",
      url: "https://liquidroom.net",
      complexity: :high,
      strategy: :hybrid_browser,
      selectors: {
        gigs: '.event, .schedule-item, .live-info, article',
        title: 'h2, h3, .title, .event-title',
        date: '.date, .event-date, time',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    },
    {
      name: "Zepp Tokyo",
      url: "https://zepp.co.jp/tokyo/",
      complexity: :high,
      strategy: :hybrid_browser,
      selectors: {
        gigs: '.event-item, .schedule-item, .live-info',
        title: 'h3, .title, .event-title',
        date: '.date, .event-date',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    },
    {
      name: "Club Quattro Shibuya",
      url: "https://www.club-quattro.com/shibuya/",
      complexity: :medium,
      strategy: :hybrid_http_first,
      selectors: {
        gigs: '.event-item, .schedule-item, .live-info',
        title: 'h3, .title, .event-title',
        date: '.date, .event-date',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    },
    {
      name: "Shinjuku Loft",
      url: "https://www.loft-prj.co.jp/schedule/loft/",
      complexity: :medium,
      strategy: :hybrid_http_first,
      selectors: {
        gigs: '.schedule-item, .event-item, .live-info',
        title: 'h3, .title, .event-title',
        date: '.date, .event-date',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    },
    {
      name: "Shibuya WWW",
      url: "https://www-shibuya.jp",
      complexity: :high,
      strategy: :hybrid_browser,
      selectors: {
        gigs: '.event, .schedule-item, .live-info',
        title: 'h2, h3, .title, .event-title',
        date: '.date, .event-date',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    },
    {
      name: "Shibuya WWW X",
      url: "https://www-shibuya.jp/wwwx/",
      complexity: :high,
      strategy: :hybrid_browser,
      selectors: {
        gigs: '.event, .schedule-item, .live-info',
        title: 'h2, h3, .title, .event-title',
        date: '.date, .event-date',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    },
    {
      name: "Harajuku Astro Hall",
      url: "https://www.astro-hall.com",
      complexity: :medium,
      strategy: :hybrid_http_first,
      selectors: {
        gigs: '.event-item, .schedule-item, .live-info',
        title: 'h3, .title, .event-title',
        date: '.date, .event-date',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    },
    {
      name: "Ebisu Liquidroom",
      url: "https://liquidroom.net/ebisu/",
      complexity: :high,
      strategy: :hybrid_browser,
      selectors: {
        gigs: '.event, .schedule-item, .live-info',
        title: 'h2, h3, .title, .event-title',
        date: '.date, .event-date',
        time: '.time, .start-time',
        artists: '.artist, .performer'
      }
    }
  ]

  # Enhanced social media detection
  def is_social_media_only_venue?(url)
    return true if url.nil? || url.strip.empty?

    social_media_domains = [
      'instagram.com', 'facebook.com', 'twitter.com', 'x.com',
      'tiktok.com', 'youtube.com', 'linktr.ee', 'linktree.com',
      'ameblo.jp', 'note.com'
    ]

    # Check if URL is primarily social media
    uri = URI.parse(url.strip) rescue nil
    return false unless uri&.host

    social_media_domains.any? { |domain| uri.host.include?(domain) }
  end

  # Detect if venue redirects to social media for schedule info
  def is_social_media_redirect_venue?(venue_name, url, content = nil)
    # Check content for social media redirect indicators (but not MITSUKI)
    if content && !venue_name.include?('MITSUKI') && !venue_name.include?('翠月')
      social_redirect_indicators = [
        /check.*latest.*information.*on.*instagram/i,
        /follow.*us.*on.*instagram/i,
        /see.*our.*instagram/i,
        /visit.*our.*instagram/i,
        /instagram.*for.*updates/i,
        /schedule.*on.*instagram/i
      ]

      return social_redirect_indicators.any? { |pattern| content.match?(pattern) }
    end

    false
  end

  # Special handling for MITSUKI venue (Instagram redirect)
  def handle_mitsuki_instagram_redirect(venue_config)
    puts "    🔍 MITSUKI detected: Instagram-redirect venue" if @verbose
    puts "    📱 This venue uses Instagram for schedule updates" if @verbose
    puts "    💡 Suggestion: Check their Instagram for current events" if @verbose
    puts "    ⏭️  Skipping automated scraping for this venue" if @verbose

    # Return empty array since we can't scrape Instagram directly
    # But we could potentially add Instagram scraping in the future
    []
  end

  # Detect if venue uses image-based schedules
  def is_image_based_schedule_venue?(venue_name, url, content = nil)
    # MITSUKI is known to use image-based schedules
    return true if venue_name.include?('MITSUKI') || venue_name.include?('翠月')

    # Could add more venues here that use image schedules
    false
  end

  # Special handling for image-based schedule venues
  def handle_image_based_schedule_venue(venue_config)
    puts "    🖼️  Image-based schedule detected: #{venue_config[:name]}" if @verbose
    puts "    🔍 Using smart OCR fallback to extract text from schedule images..." if @verbose

    begin
      # Get the website content first
      content = get_website_content(venue_config[:url])
      return [] unless content

      # Find all images and PDFs on the page
      images_data = extract_schedule_images(content, venue_config)
      pdf_data = extract_schedule_pdfs(content, venue_config)

      # Try PDF extraction first (often more reliable than images)
      if pdf_data.any?
        puts "    📄 Found #{pdf_data.count} potential schedule PDFs" if @verbose

        pdf_gigs = PdfOcrService.extract_text_from_pdfs(pdf_data)

        if pdf_gigs.any?
          puts "    ✅ PDF extraction found #{pdf_gigs.count} gigs!" if @verbose
          return pdf_gigs
        else
          puts "    ⚠️  PDF extraction found no gigs" if @verbose
        end
      end

      if images_data.any?
        puts "    📸 Found #{images_data.count} potential schedule images" if @verbose

        # Use smart fallback OCR strategy
        ocr_gigs = extract_with_smart_ocr_fallback(images_data, venue_config)

        if ocr_gigs.any?
          puts "    ✅ Smart OCR extracted #{ocr_gigs.count} gigs from images" if @verbose
          return ocr_gigs
        else
          puts "    ⚠️  Smart OCR found no gigs in static images" if @verbose
        end
      else
        puts "    ❌ No schedule images found in static content" if @verbose
      end

      # Fallback: Try browser automation to find dynamically loaded images
      puts "    🔄 Trying browser automation for dynamic content..." if @verbose
      begin
        browser_gigs = extract_images_with_browser(venue_config)
        if browser_gigs.any?
          puts "    ✅ Browser OCR extracted #{browser_gigs.count} gigs!" if @verbose
          return browser_gigs
        end
      rescue => e
        puts "    ⚠️  Browser fallback failed: #{e.message}" if @verbose
      end

    rescue => e
      puts "    ❌ OCR processing failed: #{e.message}" if @verbose
      Rails.logger.warn "OCR processing failed for #{venue_config[:name]}: #{e.message}"
    end

    []
  end

  # Smart OCR fallback strategy - tries engines in order of effectiveness
  def extract_with_smart_ocr_fallback(images_data, venue_config)
    venue_name = venue_config[:name]

    # Venue-specific OCR optimization (Phase 3)
    primary_engine = get_optimal_ocr_engine(venue_name)

    # Try primary engine first
    puts "    🎯 Trying #{primary_engine[:name]} (optimal for this venue)..." if @verbose
    begin
      gigs = primary_engine[:service].extract_text_from_images(images_data)
      if gigs.any?
        puts "    ✅ #{primary_engine[:name]} extracted #{gigs.count} gigs" if @verbose
        # Record success for future optimization
        record_ocr_success(venue_name, primary_engine[:name], gigs.count)
        return gigs
      else
        puts "    ⚠️  #{primary_engine[:name]} found no gigs, trying fallback..." if @verbose
      end
    rescue => e
      puts "    ❌ #{primary_engine[:name]} failed: #{e.message}" if @verbose
      Rails.logger.warn "#{primary_engine[:name]} failed for #{venue_name}: #{e.message}"
    end

    # Fallback engines in order of general effectiveness
    fallback_engines = get_fallback_ocr_engines(primary_engine[:name])

    fallback_engines.each do |engine|
      puts "    🔄 Trying fallback: #{engine[:name]}..." if @verbose

      begin
        gigs = engine[:service].extract_text_from_images(images_data)

        if gigs.any?
          puts "    ✅ #{engine[:name]} extracted #{gigs.count} gigs!" if @verbose
          # Record success for future optimization
          record_ocr_success(venue_name, engine[:name], gigs.count)
          return gigs
        else
          puts "    ⚠️  #{engine[:name]} found no gigs" if @verbose
        end
      rescue => e
        puts "    ❌ #{engine[:name]} failed: #{e.message}" if @verbose
        Rails.logger.warn "#{engine[:name]} failed for #{venue_name}: #{e.message}"
      end
    end

    # No engines found gigs
    puts "    ❌ All OCR engines failed to extract gigs" if @verbose
    []
  end

  # Get optimal OCR engine for a specific venue (Phase 3: Venue-specific optimization)
  def get_optimal_ocr_engine(venue_name)
    # Load venue-specific OCR preferences
    ocr_preferences = load_venue_ocr_preferences

    # Check if we have a learned preference for this venue
    if ocr_preferences[venue_name]
      preferred_engine = ocr_preferences[venue_name]
      puts "    🧠 Using learned preference: #{preferred_engine} for #{venue_name}" if @verbose
      return get_ocr_engine_by_name(preferred_engine)
    end

    # Venue-specific defaults based on known performance
    case venue_name
    when /MITSUKI|翠月/
      { name: 'EasyOCR', service: EasyOcrService }
    when /Ruby Room|Heaven's Door/
      { name: 'Tesseract', service: OcrService }  # Fast for English text
    else
      # Default: EasyOCR (best general performance)
      { name: 'EasyOCR', service: EasyOcrService }
    end
  end

  # Get fallback engines excluding the primary
  def get_fallback_ocr_engines(primary_engine_name)
    all_engines = [
      { name: 'EasyOCR', service: EasyOcrService },
      { name: 'Tesseract', service: OcrService },
      { name: 'PaddleOCR', service: PaddleOcrService }
    ]

    # Return engines excluding the primary, in order of general effectiveness
    all_engines.reject { |engine| engine[:name] == primary_engine_name }
  end

  # Get OCR engine by name
  def get_ocr_engine_by_name(engine_name)
    case engine_name
    when 'EasyOCR'
      { name: 'EasyOCR', service: EasyOcrService }
    when 'Tesseract'
      { name: 'Tesseract', service: OcrService }
    when 'PaddleOCR'
      { name: 'PaddleOCR', service: PaddleOcrService }
    else
      { name: 'EasyOCR', service: EasyOcrService }  # Default
    end
  end

  # Record OCR success for future optimization
  def record_ocr_success(venue_name, engine_name, gig_count)
    return unless gig_count > 0

    preferences_file = Rails.root.join('tmp', 'venue_ocr_preferences.json')
    preferences = load_venue_ocr_preferences

    # Update preference for this venue
    preferences[venue_name] = engine_name

    # Save updated preferences
    File.write(preferences_file, JSON.pretty_generate(preferences))
    puts "    📝 Recorded #{engine_name} success for #{venue_name}" if @verbose
  rescue => e
    Rails.logger.warn "Failed to record OCR preference: #{e.message}"
  end

  # Load venue-specific OCR preferences
  def load_venue_ocr_preferences
    preferences_file = Rails.root.join('tmp', 'venue_ocr_preferences.json')

    if File.exist?(preferences_file)
      JSON.parse(File.read(preferences_file))
    else
      {}
    end
  rescue => e
    Rails.logger.warn "Failed to load OCR preferences: #{e.message}"
    {}
  end

  def get_website_content(url)
    begin
      response = HTTParty.get(url, timeout: 10, headers: {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      })

      return response.body if response.success?
    rescue => e
      Rails.logger.warn "Failed to get website content for #{url}: #{e.message}"
    end

    nil
  end

  # Extract schedule PDFs from website content
  def extract_schedule_pdfs(content, venue_config)
    return [] unless content

    pdf_data = []
    venue_name = venue_config[:name]

    # Parse HTML content
    doc = Nokogiri::HTML(content)

    # Find PDF links
    pdf_links = doc.css('a[href$=".pdf"], a[href*=".pdf"]')

    pdf_links.each do |link|
      href = link['href']
      next if href.blank?

      # Convert relative URLs to absolute
      pdf_url = resolve_url(href, venue_config[:url])
      next if pdf_url.blank?

      # Get link text and context for relevance scoring
      link_text = link.text.strip
      alt_text = link['title'] || link['alt'] || ''

      # Score PDF relevance
      relevance_score = score_pdf_relevance(pdf_url, link_text, alt_text, venue_name)

      if relevance_score > 0
        pdf_data << {
          url: pdf_url,
          alt: "#{link_text} #{alt_text}".strip,
          venue_name: venue_name,
          relevance_score: relevance_score
        }
      end
    end

    # Sort by relevance score (highest first)
    pdf_data.sort_by { |pdf| -pdf[:relevance_score] }
  end

  # Score PDF relevance for schedule content
  def score_pdf_relevance(pdf_url, link_text, alt_text, venue_name)
    score = 0
    combined_text = "#{pdf_url} #{link_text} #{alt_text}".downcase

    # High relevance indicators
    high_relevance_terms = [
      'schedule', 'スケジュール', 'event', 'イベント', 'live', 'ライブ',
      'concert', 'コンサート', 'show', 'ショー', 'gig', 'performance',
      'lineup', 'ラインアップ', 'program', 'プログラム', 'flyer', 'フライヤー',
      'calendar', 'カレンダー', 'timetable', 'タイムテーブル'
    ]

    high_relevance_terms.each do |term|
      score += 15 if combined_text.include?(term)
    end

    # Medium relevance indicators
    medium_relevance_terms = [
      'info', '情報', 'news', 'ニュース', 'update', 'アップデート',
      'announcement', 'お知らせ', 'notice', '通知'
    ]

    medium_relevance_terms.each do |term|
      score += 8 if combined_text.include?(term)
    end

    # Date patterns in filename (good indicator)
    if pdf_url.match(/\d{4}[-_]\d{2}[-_]\d{2}/) || pdf_url.match(/\d{2}[-_]\d{2}[-_]\d{4}/)
      score += 12
    end

    # Month names
    month_patterns = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月'
    ]

    month_patterns.each do |month|
      score += 10 if combined_text.include?(month)
    end

    # Negative indicators (reduce score)
    negative_terms = [
      'menu', 'メニュー', 'food', '食べ物', 'drink', '飲み物',
      'map', '地図', 'access', 'アクセス', 'contact', '連絡',
      'about', 'について', 'history', '歴史', 'staff', 'スタッフ'
    ]

    negative_terms.each do |term|
      score -= 5 if combined_text.include?(term)
    end

    # Ensure minimum score is 0
    [score, 0].max
  end

  # Helper method to resolve URLs
  def resolve_url(href, base_url)
    return nil if href.blank?
    return href if href.start_with?('http')

    begin
      base_uri = URI.parse(base_url)
      if href.start_with?('//')
        "#{base_uri.scheme}:#{href}"
      elsif href.start_with?('/')
        "#{base_uri.scheme}://#{base_uri.host}#{href}"
      else
        "#{base_uri.scheme}://#{base_uri.host}/#{href}"
      end
    rescue URI::InvalidURIError
      Rails.logger.warn "Invalid URL when resolving: #{href} from #{base_url}"
      nil
    end
  end

  def extract_schedule_images(html_content, venue_config)
    return [] unless html_content

    doc = Nokogiri::HTML(html_content)
    images_data = []
    base_url = venue_config[:url]

    # Find images that are likely to contain schedule information
    schedule_keywords = [
      'schedule', 'スケジュール', '予定', '日程', 'calendar', 'カレンダー',
      'event', 'イベント', 'live', 'ライブ', 'gig', 'show', 'concert'
    ]

        # Look for images with schedule-related attributes
    img_selectors = [
      'img[src*="schedule"]',
      'img[src*="calendar"]',
      'img[alt*="schedule"]',
      'img[alt*="スケジュール"]',
      'img[alt*="予定"]',
      'img[class*="schedule"]',
      'img[class*="calendar"]',
      'img[src*="event"]',
      'img[src*="live"]',
      'img[src*="gig"]',
      'img' # Fallback: all images
    ]

    img_selectors.each do |selector|
      doc.css(selector).each do |img|
        next unless img['src']

        # Convert relative URLs to absolute
        img_url = resolve_image_url(img['src'], base_url)
        next unless img_url

        # Check if this looks like a schedule image
        alt_text = img['alt'] || ''
        class_attr = img['class'] || ''
        src_attr = img['src'] || ''

        # Score the image based on likelihood of containing schedule info
        relevance_score = calculate_image_relevance_score(alt_text, class_attr, src_attr, schedule_keywords, venue_config)

        # Only include images that seem relevant (score > 0)
        if relevance_score > 0
          puts "    📷 Found image: #{File.basename(img_url)} (score: #{relevance_score})" if @verbose
          images_data << {
            url: img_url,
            alt: alt_text,
            venue_name: venue_config[:name],
            relevance_score: relevance_score
          }
        end
      end
    end

    # Sort by relevance score (highest first) and limit to top 5 images
    images_data.sort_by { |img| -img[:relevance_score] }.first(5)
  end

  def resolve_image_url(src, base_url)
    return nil if src.blank?

    # If already absolute URL, return as-is
    return src if src.start_with?('http')

    # Handle relative URLs
    begin
      base_uri = URI.parse(base_url)
      if src.start_with?('//')
        # Protocol-relative URL
        "#{base_uri.scheme}:#{src}"
      elsif src.start_with?('/')
        # Absolute path
        "#{base_uri.scheme}://#{base_uri.host}#{src}"
      else
        # Relative path
        "#{base_uri.scheme}://#{base_uri.host}/#{src}"
      end
    rescue URI::InvalidURIError
      Rails.logger.warn "Invalid URL when resolving image: #{src} from #{base_url}"
      nil
    end
  end

  def calculate_image_relevance_score(alt_text, class_attr, src_attr, schedule_keywords, venue_config = nil)
    score = 0
    text_to_check = "#{alt_text} #{class_attr} #{src_attr}".downcase

    # High-value schedule keywords
    high_value_keywords = ['schedule', 'スケジュール', 'calendar', 'カレンダー', '予定']
    medium_value_keywords = ['event', 'イベント', 'live', 'ライブ', '日程']

    # Score based on keyword matches
    high_value_keywords.each do |keyword|
      score += 10 if text_to_check.include?(keyword.downcase)
    end

    medium_value_keywords.each do |keyword|
      score += 5 if text_to_check.include?(keyword.downcase)
    end

    # Bonus for images that are likely large enough to contain readable text
    score += 3 if alt_text.length > 0 # Has descriptive alt text
    score += 2 if class_attr.include?('schedule') || class_attr.include?('calendar')

    # Give a baseline score to any image that might contain text (if not penalized)
    if score == 0 && !text_to_check.include?('logo') && !text_to_check.include?('icon')
      score += 1 # Minimal baseline score for potential text-containing images
    end

    # Special handling for MITSUKI: IMG_*.jpeg files are likely schedule flyers
    if venue_config && (venue_config[:name].include?('MITSUKI') || venue_config[:name].include?('翠月'))
      if src_attr.match?(/IMG_\d+\.jpeg/i)
        score += 15 # High score for uploaded images that could be schedule flyers
        puts "    🎯 MITSUKI special: Found potential schedule flyer #{File.basename(src_attr)}" if @verbose
      end
    end

    # Penalty for obviously non-schedule images
    penalty_keywords = ['logo', 'icon', 'banner', 'ad', 'advertisement', 'thumbnail', 'map', 'location', 'access', 'contact']
    penalty_keywords.each do |keyword|
      score -= 5 if text_to_check.include?(keyword)
    end

    # Strong penalty for SVG and other vector formats (OCR can't process these)
    score -= 10 if src_attr.include?('.svg') || src_attr.include?('.pdf')

    # Ensure score doesn't go negative
    [score, 0].max
  end

  def extract_images_with_browser(venue_config)
    gigs = []

    with_optimized_browser do |browser|
      begin
        browser.navigate.to(venue_config[:url])
        sleep(3) # Wait for dynamic content to load

        # Find all images on the page using browser
        images = browser.find_elements(tag_name: 'img')

        puts "    🔍 Browser found #{images.count} total images"

        schedule_images = []
        images.each do |img|
          begin
            src = img.attribute('src')
            next unless src && !src.include?('.svg') && !src.include?('data:')

            alt = img.attribute('alt') || ''

                                    # Score relevance
            score = calculate_image_relevance_score(alt, '', src, [], venue_config)

            # Debug: Show all images with their scores
            if @verbose
              puts "    🔍 Image: #{File.basename(src)} | Alt: '#{alt}' | Score: #{score}"
            end

            if score > 0
              puts "    📷 Browser found potential schedule image: #{File.basename(src)} (score: #{score})" if @verbose
              schedule_images << {
                url: src,
                alt: alt,
                venue_name: venue_config[:name],
                relevance_score: score
              }
            end
          rescue => e
            # Skip problematic images
            next
          end
        end

        # Try OCR on browser-found images
        if schedule_images.any?
          puts "    📸 Processing #{schedule_images.count} browser-found images with OCR"
          gigs = OcrService.extract_text_from_images(schedule_images.sort_by { |img| -img[:relevance_score] }.first(3))
        end

      rescue => e
        puts "    ❌ Browser automation failed: #{e.message}" if @verbose
      end
    end

    gigs
  end

  def initialize(options = {})
    @logger = Rails.logger
    @verbose = options[:verbose] || false
    @max_parallel_venues = options[:max_parallel_venues] || 3
    @enable_js = options[:enable_js] || true
    @responsible_mode = options[:responsible_mode] || false
    @rate_limiting = options[:rate_limiting] || false
    @respect_robots = options[:respect_robots] || false
    @user_agent = options[:user_agent]

    # Load caches
    @website_complexity_cache = load_complexity_cache
    @venue_blacklist = load_venue_blacklist

    # 🛡️ PRODUCTION SAFEGUARDS
    @memory_monitor = MemoryMonitor.new
    @circuit_breaker = CircuitBreaker.new
    @adaptive_rate_limiter = AdaptiveRateLimiter.new
    @db_connection_manager = DatabaseConnectionManager.new

    puts "🚀 UnifiedVenueScraper initialized with production safeguards" if @verbose
    puts "   📊 Max parallel venues: #{@max_parallel_venues}" if @verbose
    puts "   🛡️ Responsible mode: #{@responsible_mode}" if @verbose
    puts "   💾 Memory monitoring: enabled" if @verbose
    puts "   🔄 Circuit breaker: enabled" if @verbose
  end

  # 🛡️ Production Safeguards Classes
  class MemoryMonitor
    def initialize
      @start_memory = memory_usage
      @peak_memory = @start_memory
    end

    def check_memory_usage
      current = memory_usage
      @peak_memory = [current, @peak_memory].max

      if current > 1000 # 1GB threshold
        Rails.logger.warn "⚠️ High memory usage: #{current}MB"
        GC.start # Force garbage collection
      end

      current
    end

    def memory_report
      current = memory_usage
      {
        start: @start_memory,
        current: current,
        peak: @peak_memory,
        increase: current - @start_memory
      }
    end

    private

    def memory_usage
      `ps -o rss= -p #{Process.pid}`.to_i / 1024 # MB
    rescue
      0
    end
  end

  class CircuitBreaker
    def initialize
      @failure_counts = {}
      @last_failure_time = {}
      @failure_threshold = 3
      @timeout = 300 # 5 minutes
    end

    def call(venue_name)
      if circuit_open?(venue_name)
        Rails.logger.info "🔴 Circuit breaker OPEN for #{venue_name}"
        return { success: false, reason: "Circuit breaker open" }
      end

      begin
        result = yield
        record_success(venue_name) if result[:success]
        result
      rescue => e
        record_failure(venue_name)
        raise e
      end
    end

    private

    def circuit_open?(venue_name)
      failures = @failure_counts[venue_name] || 0
      last_failure = @last_failure_time[venue_name]

      failures >= @failure_threshold &&
        last_failure &&
        (Time.current - last_failure) < @timeout
    end

    def record_failure(venue_name)
      @failure_counts[venue_name] = (@failure_counts[venue_name] || 0) + 1
      @last_failure_time[venue_name] = Time.current
    end

    def record_success(venue_name)
      @failure_counts[venue_name] = 0
      @last_failure_time.delete(venue_name)
    end
  end

  class AdaptiveRateLimiter
    def initialize
      @response_times = {}
      @base_delay = 1.0
      @max_delay = 10.0
    end

    def delay_for_venue(venue_name)
      avg_response_time = @response_times[venue_name] || 1.0

      # Adaptive delay based on response time
      delay = [@base_delay + (avg_response_time * 0.5), @max_delay].min

      Rails.logger.debug "⏱️ Adaptive delay for #{venue_name}: #{delay}s"
      sleep(delay)
    end

    def record_response_time(venue_name, time)
      @response_times[venue_name] = (@response_times[venue_name] || 0) * 0.7 + time * 0.3
    end
  end

  class DatabaseConnectionManager
    def initialize
      @connection_semaphore = Concurrent::Semaphore.new(3) # Limit concurrent DB operations
    end

    def with_connection
      @connection_semaphore.acquire
      begin
        ActiveRecord::Base.connection_pool.with_connection do
          yield
        end
      ensure
        @connection_semaphore.release
      end
    end
  end

  def test_proven_venues(options = {})
    puts "🧪 Testing our 5 proven venues with optimized Selenium WebDriver..."
    @verbose = options[:verbose] || false

    all_gigs = []
    successful_venues = 0
    failed_venues = []

    PROVEN_VENUES.each_with_index do |venue_config, index|
      puts "\n" + "="*60
      puts "TESTING PROVEN VENUE #{index + 1}/#{PROVEN_VENUES.count}: #{venue_config[:name]}"
      puts "URL: #{venue_config[:url]}"
      puts "="*60

            begin
        puts "🔍 Starting OPTIMIZED scrape for #{venue_config[:name]}..."
        gigs = scrape_venue_optimized(venue_config)
        puts "📊 Raw scraping complete: found #{gigs.count} total gigs"

        if gigs && gigs.any?
          puts "🔧 Filtering gigs for validity..."
          valid_gigs = filter_valid_gigs(gigs)
          puts "📋 Filtering complete: #{valid_gigs.count}/#{gigs.count} gigs passed validation"

          if gigs.count > valid_gigs.count
            filtered_out = gigs.count - valid_gigs.count
            puts "⚠️  Filtered out #{filtered_out} gigs (duplicates, past dates, or invalid)"

            # Show some examples of what was filtered out
            begin
              invalid_gigs = gigs - valid_gigs
              if invalid_gigs.respond_to?(:first) && invalid_gigs.any?
                invalid_gigs.first(3).each do |gig|
                  if gig.is_a?(Hash)
                    puts "    ❌ Filtered: #{gig[:date]} - #{gig[:title]} (#{gig[:title] ? 'has title' : 'no title'})"
                  end
                end
              end
            rescue => e
              puts "    ⚠️  Could not show filtered gigs: #{e.message}"
            end
          end

          if valid_gigs.any?
            puts "✅ SUCCESS: Found #{valid_gigs.count} valid gigs for #{venue_config[:name]}"

            # 💾 Save to database
            db_result = save_gigs_to_database(valid_gigs, venue_config[:name])
            puts "    💾 Database: #{db_result[:saved]} saved, #{db_result[:skipped]} skipped" if @verbose

            all_gigs.concat(valid_gigs)
            successful_venues += 1

            # Show some examples
            puts "📅 Sample valid gigs:"
            begin
              valid_gigs.first(3).each do |gig|
                if gig.is_a?(Hash)
                  puts "    ✓ #{gig[:date]} - #{gig[:title]}"
                end
              end
            rescue => e
              puts "    ⚠️  Could not display sample gigs: #{e.message}"
            end
          else
            puts "⚠️  NO VALID GIGS: #{venue_config[:name]} - found #{gigs.count} gigs but none were valid/current"
            failed_venues << { venue: venue_config[:name], reason: "No valid current gigs" }
          end
        else
          puts "❌ NO GIGS: #{venue_config[:name]} - no gigs found"
          failed_venues << { venue: venue_config[:name], reason: "No gigs found" }
        end

      rescue => e
        puts "❌ ERROR: #{venue_config[:name]} - #{e.message}"
        failed_venues << { venue: venue_config[:name], reason: e.message }
      end

      sleep(1) # Brief pause between venues (reduced for speed)
    end

    # Save results
    save_results(all_gigs, "proven_venues_selenium_test.json")

    puts "\n" + "="*60
    puts "PROVEN VENUES TEST COMPLETE!"
    puts "="*60
    puts "✅ Successful venues: #{successful_venues}/#{PROVEN_VENUES.count}"
    puts "📊 Total gigs found: #{all_gigs.count}"
    puts "❌ Failed venues: #{failed_venues.count}"

    if failed_venues.any?
      puts "\n📋 FAILURES:"
      failed_venues.each { |failure| puts "  • #{failure[:venue]} - #{failure[:reason]}" }
    end

    {
      successful_venues: successful_venues,
      total_gigs: all_gigs.count,
      failed_venues: failed_venues,
      gigs: all_gigs
    }
  end

  def limited_n_plus_one_test(limit = 15)
    puts "🚀 Starting Limited N+1 Venue Test (#{limit} venues)..."

    # Get our baseline from proven venues
    baseline_result = test_proven_venues
    puts "\n📊 BASELINE: #{baseline_result[:successful_venues]} proven venues, #{baseline_result[:total_gigs]} gigs"

    # Get candidate venues for testing (filtered, high-potential)
    candidate_venues = get_candidate_venues(limit)
    puts "\n🎯 Testing #{candidate_venues.count} candidate venues..."

    all_gigs = baseline_result[:gigs].dup
    successful_venues = baseline_result[:successful_venues]
    failed_venues = baseline_result[:failed_venues].dup
    venues_to_delete = []

    candidate_venues.each_with_index do |venue, index|
      puts "\n" + "-"*50
      puts "TESTING CANDIDATE #{index + 1}/#{candidate_venues.count}: #{venue.name}"
      puts "URL: #{venue.website}"
      puts "-"*50

      begin
        if website_accessible?(venue.website)
          venue_config = {
            name: venue.name,
            url: venue.website,
            selectors: get_general_selectors
          }

          gigs = scrape_venue(venue_config)

          if gigs && gigs.any?
            valid_gigs = filter_valid_gigs(gigs)

            if valid_gigs.any?
              puts "✅ SUCCESS: Found #{valid_gigs.count} valid gigs for #{venue.name}"

              # 💾 Save to database
              db_result = save_gigs_to_database(valid_gigs, venue.name)
              puts "    💾 Database: #{db_result[:saved]} saved, #{db_result[:skipped]} skipped" if @verbose

              all_gigs.concat(valid_gigs)
              successful_venues += 1

              # Show examples
              valid_gigs.first(2).each do |gig|
                puts "  📅 #{gig[:date]} - #{gig[:title]}"
              end
            else
              puts "⚠️  NO VALID GIGS: #{venue.name}"
              failed_venues << { venue: venue.name, url: venue.website, reason: "No valid current gigs" }
            end
          else
            puts "⚠️  NO GIGS: #{venue.name}"
            failed_venues << { venue: venue.name, url: venue.website, reason: "No gigs found" }
          end
        else
          puts "❌ DEAD WEBSITE: #{venue.name} - marking for deletion"
          venues_to_delete << venue
          failed_venues << { venue: venue.name, url: venue.website, reason: "Dead website - will be deleted" }
        end

      rescue => e
        puts "❌ ERROR: #{venue.name} - #{e.message}"
        failed_venues << { venue: venue.name, url: venue.website, reason: e.message }
      end

      sleep(2) # Rate limiting
    end

    # Clean up dead venues
    if venues_to_delete.any?
      puts "\n🗑️  DELETING #{venues_to_delete.count} DEAD VENUES:"
      venues_to_delete.each do |venue|
        puts "  Deleting: #{venue.name}"
        begin
          venue.destroy!
        rescue ActiveRecord::InvalidForeignKey => e
          puts "    ⚠️  Cannot delete #{venue.name} - has existing gigs. Updating website to NULL instead."
          venue.update!(website: nil)
        rescue => e
          puts "    ❌ Error deleting #{venue.name}: #{e.message}"
        end
      end
    end

    # Save results
    save_results(all_gigs, "limited_n_plus_one_test.json")

    puts "\n" + "="*60
    puts "LIMITED N+1 TEST COMPLETE!"
    puts "="*60
    puts "✅ Total successful venues: #{successful_venues}"
    puts "📊 Total gigs found: #{all_gigs.count}"
    puts "🆕 New venues added: #{successful_venues - baseline_result[:successful_venues]}"
    puts "❌ Failed venues: #{failed_venues.count - baseline_result[:failed_venues].count}"
    puts "🗑️  Deleted dead venues: #{venues_to_delete.count}"

    {
      total_successful_venues: successful_venues,
      total_gigs: all_gigs.count,
      new_venues_added: successful_venues - baseline_result[:successful_venues],
      failed_venues: failed_venues,
      deleted_venues: venues_to_delete.count
    }
  end

  # 🚀 ULTRA-FAST PARALLEL PROCESSING VERSION
  def test_proven_venues_parallel(options = {})
    puts "🚀 ULTRA-FAST PARALLEL VENUE SCRAPING..."
    @verbose = options[:verbose] || false

    start_time = Time.current
    all_gigs = []
    successful_venues = 0
    failed_venues = []

    # Create thread pool for parallel processing
    thread_pool = Concurrent::FixedThreadPool.new(@max_parallel_venues)
    futures = []

    puts "⚡ Processing #{PROVEN_VENUES.count} venues with #{@max_parallel_venues} parallel threads..."

    PROVEN_VENUES.each_with_index do |venue_config, index|
      future = Concurrent::Future.execute(executor: thread_pool) do
        puts "\n🔄 [Thread #{Thread.current.object_id}] Starting #{venue_config[:name]}..." if @verbose

        begin
          # Try HTTP-first approach for speed
          result = scrape_venue_ultra_fast(venue_config)

          if result[:success]
            puts "✅ [#{venue_config[:name]}] SUCCESS: #{result[:gigs].count} gigs" if @verbose

            # 💾 Save to database in parallel thread
            begin
              db_result = save_gigs_to_database(result[:gigs], venue_config[:name])
              puts "    💾 [#{venue_config[:name]}] Database: #{db_result[:saved]} saved" if @verbose
            rescue => e
              puts "    ❌ [#{venue_config[:name]}] Database error: #{e.message}" if @verbose
            end

            { success: true, venue: venue_config[:name], gigs: result[:gigs] }
          else
            puts "❌ [#{venue_config[:name]}] #{result[:reason]}" if @verbose
            { success: false, venue: venue_config[:name], reason: result[:reason], gigs: [] }
          end

        rescue => e
          puts "❌ [#{venue_config[:name]}] ERROR: #{e.message}" if @verbose
          { success: false, venue: venue_config[:name], reason: e.message, gigs: [] }
        end
      end

      futures << future
    end

    # Wait for all threads to complete and collect results
    puts "\n⏳ Waiting for all parallel scraping to complete..."

    results = futures.map(&:value)
    thread_pool.shutdown
    thread_pool.wait_for_termination(30) # 30 second timeout

    # Process results
    results.each do |result|
      if result[:success]
        successful_venues += 1
        all_gigs.concat(result[:gigs])
      else
        failed_venues << { venue: result[:venue], reason: result[:reason] }
      end
    end

    end_time = Time.current
    duration = (end_time - start_time).round(2)

    # Save results
    save_results(all_gigs, "parallel_proven_venues_test.json")

    puts "\n" + "="*60
    puts "PARALLEL PROCESSING COMPLETE!"
    puts "="*60
    puts "⚡ Total time: #{duration} seconds"
    puts "✅ Successful venues: #{successful_venues}/#{PROVEN_VENUES.count}"
    puts "📊 Total gigs found: #{all_gigs.count}"
    puts "🏎️  Average time per venue: #{(duration / PROVEN_VENUES.count).round(2)} seconds"
    puts "🚀 Speed improvement: ~#{((466.66 / duration) * 100).round(0)}% faster than sequential!"

    if failed_venues.any?
      puts "\n❌ Failed venues:"
      failed_venues.each { |failure| puts "  • #{failure[:venue]} - #{failure[:reason]}" }
    end

    # Save cache
    save_complexity_cache

    {
      successful_venues: successful_venues,
      total_gigs: all_gigs.count,
      failed_venues: failed_venues,
      gigs: all_gigs,
      duration: duration
    }
  end

  # 🏎️ HTTP-FIRST ULTRA-FAST SCRAPING
  def scrape_venue_ultra_fast(venue_config)
    puts "🏎️ [#{venue_config[:name]}] Starting ultra-fast scraping..." if @verbose

    # Check blacklist first - but be less aggressive
    if is_venue_blacklisted?(venue_config[:name], venue_config[:url])
      return { success: false, gigs: [], reason: "Blacklisted venue", venue: venue_config[:name] }
    end

    # 🛡️ Use circuit breaker pattern
    @circuit_breaker.call(venue_config[:name]) do
      # 📊 Monitor memory usage
      @memory_monitor.check_memory_usage

      # ⏱️ Apply adaptive rate limiting
      @adaptive_rate_limiter.delay_for_venue(venue_config[:name])

      start_time = Time.current

      # Get cached complexity or detect
      complexity = get_cached_complexity(venue_config[:url])
      gigs = []

      begin
        # Try HTTP-first for simple sites
        if complexity == :simple_html
          puts "  📄 [#{venue_config[:name]}] Using HTTP-first approach..." if @verbose
          gigs = scrape_venue_http_first(venue_config)

          if gigs.nil? || gigs.empty?
            puts "  🌐 [#{venue_config[:name]}] Using optimized browser..." if @verbose
            gigs = scrape_venue_optimized(venue_config)
          end
        else
          puts "  🌐 [#{venue_config[:name]}] Using optimized browser..." if @verbose
          gigs = scrape_venue_optimized(venue_config)
        end

        # Record response time for adaptive rate limiting
        response_time = Time.current - start_time
        @adaptive_rate_limiter.record_response_time(venue_config[:name], response_time)

        # IMPROVED: Less aggressive blacklisting
        if gigs.nil? || gigs.empty?
          # Don't blacklist immediately - many venues might just not have current gigs
          puts "  ℹ️ No gigs found for #{venue_config[:name]}" if @verbose
          return { success: false, gigs: [], reason: "No gigs found", venue: venue_config[:name] }
        end

        # Filter valid gigs
        valid_gigs = filter_valid_gigs(gigs)

        if valid_gigs.empty?
          # Don't blacklist for no valid current gigs - this is normal
          puts "  ℹ️ No valid current gigs for #{venue_config[:name]}" if @verbose
          return { success: false, gigs: [], reason: "No valid current gigs", venue: venue_config[:name] }
        end

        return { success: true, gigs: valid_gigs, venue: venue_config[:name] }

      rescue Selenium::WebDriver::Error::TimeoutError => e
        error_msg = e.message
        # Only blacklist after multiple timeout failures
        record_venue_failure(venue_config[:name], "timeout")
        if should_blacklist_venue?(venue_config[:name])
          add_to_blacklist(venue_config[:name], "repeated timeouts")
        end
        return { success: false, gigs: [], reason: "timeout: #{error_msg}", venue: venue_config[:name] }

      rescue => e
        error_msg = e.message
        # Only blacklist after multiple general failures
        record_venue_failure(venue_config[:name], "error")
        if should_blacklist_venue?(venue_config[:name])
          add_to_blacklist(venue_config[:name], "repeated errors: #{error_msg}")
        end
        return { success: false, gigs: [], reason: "ERROR: #{error_msg}", venue: venue_config[:name] }
      end
    end
  end

  # 🌐 HTTP-First Scraping (fastest for simple sites) - ENHANCED
  def scrape_venue_http_first(venue_config)
    gigs = []
    urls = venue_config[:urls] || [venue_config[:url]]

    urls.each do |url|
      begin
        puts "    📡 [#{venue_config[:name]}] HTTP GET: #{url}" if @verbose

        uri = URI(url)

        # Enhanced HTTP client with redirect handling
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 5  # Reduced timeout
        http.read_timeout = 10 # Reduced timeout

        request = Net::HTTP::Get.new(uri.path.present? ? uri.path : '/')
        request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'

        response = http.request(request)

        # Handle redirects manually
        if [301, 302, 303, 307, 308].include?(response.code.to_i)
          redirect_url = response['location']
          if redirect_url
            puts "      🔄 Following redirect: #{redirect_url}" if @verbose

            # Handle relative redirects
            if redirect_url.start_with?('/')
              redirect_url = "#{uri.scheme}://#{uri.host}#{redirect_url}"
            end

            # Try the redirect
            begin
              redirect_uri = URI(redirect_url)
              redirect_response = Net::HTTP.get_response(redirect_uri)
              if redirect_response.code == '200'
                response = redirect_response
              end
            rescue => redirect_error
              puts "      ❌ Redirect failed: #{redirect_error.message}" if @verbose
            end
          end
        end

        if response.code == '200'
          doc = Nokogiri::HTML(response.body)
          page_gigs = extract_gigs_from_page_enhanced(doc, venue_config)
          gigs.concat(page_gigs)
          puts "      ✅ Found #{page_gigs.count} gigs via HTTP" if @verbose
        else
          puts "      ⚠️ HTTP #{response.code}: #{url}" if @verbose
        end

      rescue => e
        puts "      ❌ HTTP failed: #{e.message}" if @verbose
        return nil # Fall back to browser
      end
    end

    gigs
  end

  def create_optimized_browser
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-images') # Speed optimization
    options.add_argument('--disable-css') # Speed optimization
    options.add_argument('--disable-plugins')
    options.add_argument('--disable-extensions')
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

    # Fix for Selenium Manager issues - explicitly set Chrome binary path
    options.binary = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

    # Create webdriver with explicit service configuration
    service = Selenium::WebDriver::Chrome::Service.new(path: '/opt/homebrew/bin/chromedriver')
    browser = Selenium::WebDriver.for :chrome, service: service, options: options

    # Optimized timeouts for speed
    browser.manage.timeouts.implicit_wait = 2
    browser.manage.timeouts.page_load = 8

    browser
  rescue => e
    puts "❌ Chrome browser creation failed: #{e.message}"
    puts "    Falling back to system-managed driver..."
    # Fallback without explicit paths
    browser = Selenium::WebDriver.for :chrome, options: options
    browser.manage.timeouts.implicit_wait = 2
    browser.manage.timeouts.page_load = 8
    browser
  end

  def create_enhanced_browser
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1920,1080')

    # Enhanced options for bypassing detection
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_argument('--disable-web-security')
    options.add_argument('--disable-features=VizDisplayCompositor')
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

    # Add realistic browser preferences
    prefs = {
      'profile.default_content_setting_values.notifications' => 2,
      'profile.default_content_settings.popups' => 0,
      'profile.managed_default_content_settings.images' => 2
    }
    options.add_preference(:prefs, prefs)

    # Fix for Selenium Manager issues - explicitly set Chrome binary path
    options.binary = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

    # Create webdriver with explicit service configuration
    service = Selenium::WebDriver::Chrome::Service.new(path: '/opt/homebrew/bin/chromedriver')
    browser = Selenium::WebDriver.for :chrome, service: service, options: options

    # Enhanced timeouts for complex sites
    browser.manage.timeouts.implicit_wait = 5
    browser.manage.timeouts.page_load = 15

    browser
  rescue => e
    puts "❌ Enhanced Chrome browser creation failed: #{e.message}"
    puts "    Falling back to system-managed driver..."
    # Fallback without explicit paths
    browser = Selenium::WebDriver.for :chrome, options: options
    browser.manage.timeouts.implicit_wait = 5
    browser.manage.timeouts.page_load = 15
    browser
  end

  # 🔍 Enhanced gig extraction with better selectors
  def extract_gigs_from_page_enhanced(doc, venue_config)
    gigs = []
    selectors = venue_config[:selectors] || get_general_selectors

    # Try multiple selector strategies
    selector_sets = [
      selectors&.[](:gigs), # Original selectors
      # Enhanced selectors for common patterns
      '.event-item, .schedule-row, .live-info, .show-listing, .performance, .concert-info',
      # Date-based selectors
      '[class*="date"], [class*="schedule"], [class*="event"], [class*="live"]',
      # Table-based selectors
      'table tr, tbody tr, .table-row',
      # List-based selectors
      'li, ul li, ol li, .list-item',
      # Generic content selectors
      'article, section, .content, .main, .info'
    ]

    selector_sets.each do |selector_set|
      next unless selector_set

      # Find gig elements
      gig_elements = []
      selector_set.split(', ').each do |selector|
        elements = doc.css(selector.strip)
        gig_elements.concat(elements.to_a)
      end

      # Process elements and look for date/event patterns
      gig_elements.each do |element|
        text_content = element.text.strip
        next if text_content.length < 10 # Skip very short content

        # Look for date patterns in the text
        if contains_date_pattern?(text_content)
          gig_data = extract_gig_data_enhanced(element, selectors, venue_config[:name], venue_config[:url])

          if gig_data[:title] || gig_data[:date]
            gigs << gig_data
          end
        end
      end

      # If we found gigs with this selector set, use them
      break if gigs.any?
    end

    gigs.uniq { |gig| [gig[:title], gig[:date], gig[:venue]] }
  end

  # 🔍 Enhanced gig data extraction
  def extract_gig_data_enhanced(element, selectors, venue_name, source_url)
    gig = {
      title: extract_text_by_selectors_enhanced(element, selectors[:title]),
      date: extract_and_parse_date_enhanced(element, selectors[:date]),
      time: extract_text_by_selectors_enhanced(element, selectors[:time]),
      artists: extract_text_by_selectors_enhanced(element, selectors[:artists]),
      venue: venue_name,
      source_url: source_url,
      raw_text: element.text.strip # Keep raw text for debugging
    }

    # If we didn't find structured data, try to extract from raw text
    if !gig[:title] && !gig[:date]
      text = element.text.strip

      # Try to extract date from any text in the element
      if date_match = extract_date_from_any_text(text)
        gig[:date] = date_match

        # Use the line with the date as title if no better title found
        date_line = text.lines.find { |line| contains_date_pattern?(line) }
        if date_line
          gig[:title] = clean_text(date_line.gsub(/\d{4}[-\/]\d{1,2}[-\/]\d{1,2}/, '').strip)
        end
      end
    end

    # Clean up data
    gig[:title] = clean_text(gig[:title])
    gig[:artists] = clean_text(gig[:artists])

    gig
  end

  # 🔍 Enhanced text extraction with fallbacks
  def extract_text_by_selectors_enhanced(element, selectors)
    return nil unless selectors

    # Try original selectors first
    result = extract_text_by_selectors(element, selectors)
    return result if result

    # Fallback: look for any text content that seems relevant
    element.css('*').each do |child|
      text = child.text.strip
      if text.length > 3 && text.length < 200
        return text
      end
    end

    nil
  end

  # 📅 Enhanced date extraction
  def extract_and_parse_date_enhanced(element, selectors)
    # Try standard approach first
    result = extract_and_parse_date(element, selectors)
    return result if result

    # Fallback: look for any date pattern in the element text
    extract_date_from_any_text(element.text)
  end

  # 🔍 Helper methods for pattern detection
  def contains_date_pattern?(text)
    date_patterns = [
      /\d{4}[-\/\.]\d{1,2}[-\/\.]\d{1,2}/,     # 2025-06-11, 2025/06/11, 2025.06.11
      /\d{1,2}[-\/\.]\d{1,2}[-\/\.]\d{4}/,     # 11-06-2025, 11/06/2025, 11.06.2025
      /\d{1,2}月\d{1,2}日/,                      # 6月11日
      /\d{1,2}\/\d{1,2}/,                       # 6/11
      /\d{1,2}\.\d{1,2}/,                       # 6.11
      /\d{1,2}-\d{1,2}/,                        # 6-11
      /(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/i, # Month names
      /(January|February|March|April|May|June|July|August|September|October|November|December)/i, # Full month names
      /(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/i, # Day names
      /(Mon|Tue|Wed|Thu|Fri|Sat|Sun)/i,         # Short day names
      /(今日|明日|来週|今週|本日)/,                  # Japanese relative dates
      /\d{4}年\d{1,2}月\d{1,2}日/,              # 2025年6月11日
      /\d{1,2}\/\d{1,2}\(\w+\)/,               # 6/11(Tue)
      /\d{4}\.\d{1,2}\.\d{1,2}\[\w+\]/,        # 2025.06.11[tue]
      /\d{1,2}(th|st|nd|rd)/,                   # 11th, 1st, 2nd, 3rd
      /\b\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/i, # 11 Jun
      /\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}/i  # Jun 11
    ]

    date_patterns.any? { |pattern| text.match?(pattern) }
  end

  def extract_date_from_any_text(text)
    parsed_date = parse_date_from_text(text)
    parsed_date&.strftime('%Y-%m-%d')
  end

  # 💾 Persistent Complexity Caching
  def load_complexity_cache
    cache_file = Rails.root.join('tmp', 'venue_complexity_cache.json')

    if File.exist?(cache_file)
      begin
        JSON.parse(File.read(cache_file), symbolize_names: true)
      rescue
        {}
      end
    else
      {}
    end
  end

  def save_complexity_cache
    cache_file = Rails.root.join('tmp', 'venue_complexity_cache.json')
    FileUtils.mkdir_p(File.dirname(cache_file))

    File.write(cache_file, JSON.pretty_generate(@website_complexity_cache))
    puts "💾 Complexity cache saved to #{cache_file}" if @verbose
  end

  def get_cached_complexity(url)
    cached = @website_complexity_cache[url.to_sym]
    if cached
      puts "  💾 [Cache Hit] #{url} → #{cached}" if @verbose
      return cached.to_sym
    end

    # Detect and cache
    complexity = detect_website_complexity(url)
    @website_complexity_cache[url.to_sym] = complexity
    complexity
  end

  # 🔍 Filtering method (moved to public for rake tasks)
  def filter_valid_gigs(gigs)
    return [] unless gigs

    today = Date.current
    past_cutoff = today - 30 # Allow events up to 30 days in the past (venues often keep recent events)
    future_cutoff = today + 365 # Max 1 year in future

    puts "    🔍 Filtering #{gigs.count} gigs..." if @verbose
    puts "    📅 Date range: #{past_cutoff.strftime('%Y-%m-%d')} to #{future_cutoff.strftime('%Y-%m-%d')}" if @verbose

    no_title_count = 0
    no_date_count = 0
    past_date_count = 0
    future_date_count = 0
    invalid_date_count = 0
    skip_terms_count = 0
    no_content_count = 0
    valid_count = 0

    valid_gigs = gigs.select do |gig|
      # More lenient title requirement - allow shorter titles for venue listings
      unless gig[:title].present? && gig[:title].strip.length >= 2
        no_title_count += 1
        next false
      end

      # Check for valid date range (allow recent past events)
      if gig[:date].present?
        begin
          gig_date = gig[:date].is_a?(Date) ? gig[:date] : Date.parse(gig[:date])
          if gig_date < past_cutoff
            past_date_count += 1
            next false
          elsif gig_date > future_cutoff
            future_date_count += 1
            next false
          end
        rescue
          invalid_date_count += 1
          next false
        end
      else
        no_date_count += 1
        next false
      end

      # Filter out obvious non-events
      title_lower = gig[:title].strip.downcase
      skip_terms = ['設営', '撤去', '準備', 'setup', 'teardown', 'maintenance', 'closed', 'holiday', 'menu', 'access', 'contact']
      if skip_terms.any? { |term| title_lower.include?(term) }
        skip_terms_count += 1
        next false
      end

      # MAXIMUM PERMISSIVE content validation - accept almost everything
      title = gig[:title].strip
      artists = gig[:artists]&.strip || ""

      # Only reject obvious junk/navigation elements
      junk_patterns = [
        /^(click|map|terrain|satellite|labels|styled|keyboard|shortcuts|terms|report|error|navigate|arrow|keys|zoom|home|jump|page|up|down|left|right|menu|access|contact|about|info|news|blog|shop|store)$/i,
        /^(to navigate|press the arrow|map data|google|metric|imperial|units|today's event|schedule)$/i,
        /^[<>\/\\\[\]{}().,;:!?@#$%^&*+=|`~\s]*$/, # Only symbols/whitespace
        /^.{1,2}$/, # Too short (1-2 chars)
        /^(move left|move right|move up|move down|zoom in|zoom out|home|end|page up|page down)$/i
      ]

      is_junk = junk_patterns.any? { |pattern| title.match?(pattern) }

      # Accept if it's not junk AND has any content at all
      content_valid = !is_junk && (title.present? || artists.present?)

      unless content_valid
        no_content_count += 1
        next false
      end

      valid_count += 1
      true
    end

    if @verbose
      puts "    📊 Filtering results:"
      puts "      ✅ Valid: #{valid_count}"
      puts "      ❌ No title: #{no_title_count}" if no_title_count > 0
      puts "      ❌ No date: #{no_date_count}" if no_date_count > 0
      puts "      ❌ Past date: #{past_date_count}" if past_date_count > 0
      puts "      ❌ Too far future: #{future_date_count}" if future_date_count > 0
      puts "      ❌ Invalid date: #{invalid_date_count}" if invalid_date_count > 0
      puts "      ❌ Skip terms (setup/teardown): #{skip_terms_count}" if skip_terms_count > 0
      puts "      ❌ No meaningful content: #{no_content_count}" if no_content_count > 0
    end

    valid_gigs
  end

  def get_candidate_venues(limit)
    Venue.where.not(website: [nil, ''])
         .where("website NOT LIKE '%facebook%'")
         .where("website NOT LIKE '%instagram%'")
         .where("website NOT LIKE '%twitter%'")
         .where("website NOT LIKE '%tiktok%'")
         .where("website NOT LIKE '%youtube%'")
         .where("website NOT LIKE '%blogspot%'")
         .where("website NOT LIKE '%blog%'")
         .where("website NOT LIKE '%shop%'")
         .where("website NOT LIKE '%restaurant%'")
         .where("website NOT LIKE '%cafe%'")
         .where("website NOT LIKE '%hotel%'")
         .where("website LIKE 'http%'")
         .where("name LIKE '%live%' OR name LIKE '%music%' OR name LIKE '%hall%' OR name LIKE '%club%' OR name LIKE '%studio%' OR website LIKE '%live%' OR website LIKE '%music%' OR website LIKE '%event%' OR website LIKE '%hall%' OR website LIKE '%club%' OR website LIKE '%studio%'")
         .limit(limit)
         .order(:name)
  end

  def get_general_selectors
    {
      gigs: '.event, .gig, .schedule-item, .live, .concert, article, .post, .news-item, tr, li, .show, .performance, .listing, div[class*="event"], div[class*="schedule"], div[class*="live"], div[class*="show"]',
      title: 'h1, h2, h3, h4, .title, .event-title, .gig-title, .name, .show-title, .performance-title, td:nth-child(2), a, span[class*="title"], div[class*="title"]',
      date: '.date, .event-date, .gig-date, time, .meta, .when, .datetime, td:nth-child(1), span[class*="date"], div[class*="date"], [data-date]',
      time: '.time, .start-time, .gig-time, .when, .datetime, td:nth-child(3), td:nth-child(4), span[class*="time"], div[class*="time"]',
      artists: '.artist, .performer, .lineup, .act, .band, .musicians, .acts, span[class*="artist"], div[class*="artist"]'
    }
  end

  def website_accessible?(url)
    return false unless url

    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 3
      http.read_timeout = 5

      request = Net::HTTP::Head.new(uri.path.present? ? uri.path : '/')
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'

      response = http.request(request)

      # Consider 2xx and 3xx responses as accessible
      [200, 301, 302, 303, 307, 308].include?(response.code.to_i)

    rescue => e
      false
    end
  end

  def clean_text(text)
    return nil unless text.present?
    text.strip.gsub(/\s+/, ' ')
  end

  # Website complexity detection
  def detect_website_complexity(url)
    return @website_complexity_cache[url] if @website_complexity_cache[url]

    begin
      # Quick HTTP check first
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 3
      http.read_timeout = 5

      response = http.get(uri.path.empty? ? '/' : uri.path)
      html = response.body

      complexity = analyze_html_complexity(html, url)

      # Cache the result
      @website_complexity_cache[url] = complexity
      save_complexity_cache

      complexity
    rescue => e
      puts "    ⚠️ Complexity detection failed for #{url}: #{e.message}" if @verbose
      :unknown
    end
  end

  def analyze_html_complexity(html, url)
    return :unknown unless html

    # Complexity indicators
    indicators = {
      iframe_count: html.scan(/<iframe[^>]*>/i).count,
      script_count: html.scan(/<script[^>]*>/i).count,
      dynamic_frameworks: [
        /react/i, /vue/i, /angular/i, /ember/i, /turbo/i, /stimulus/i,
        /spa/i, /single.page/i, /webpack/i, /babel/i
      ].any? { |pattern| html.match?(pattern) },
      ajax_indicators: [
        /ajax/i, /xhr/i, /fetch\(/i, /axios/i, /jquery/i,
        /data-remote/i, /data-turbo/i, /async/i
      ].any? { |pattern| html.match?(pattern) },
      minimal_content: html.length < 5000,
      noscript_warning: html.match?(/<noscript[^>]*>.*javascript.*<\/noscript>/i),
      calendar_widgets: [
        /calendar/i, /schedule/i, /datepicker/i, /fullcalendar/i
      ].any? { |pattern| html.match?(pattern) }
    }

    # Calculate complexity score
    score = 0
    score += 3 if indicators[:iframe_count] > 0  # iframes are complex
    score += 2 if indicators[:script_count] > 10 # lots of JS
    score += 2 if indicators[:dynamic_frameworks]
    score += 1 if indicators[:ajax_indicators]
    score += 2 if indicators[:noscript_warning] # requires JS
    score += 1 if indicators[:calendar_widgets]
    score -= 1 if indicators[:minimal_content] # simple pages are usually static

    # Classify complexity
    complexity = case score
                when 0..1 then :simple    # Fast scraping (HTTP only)
                when 2..4 then :moderate  # Standard Selenium
                when 5..8 then :complex   # Enhanced Selenium with waits
                else :very_complex        # Full JS interaction required
                end

    puts "    🔍 Complexity analysis for #{URI(url).host}:" if @verbose
    puts "      iframes: #{indicators[:iframe_count]}, scripts: #{indicators[:script_count]}" if @verbose
    puts "      frameworks: #{indicators[:dynamic_frameworks]}, ajax: #{indicators[:ajax_indicators]}" if @verbose
    puts "      noscript: #{indicators[:noscript_warning]}, calendar: #{indicators[:calendar_widgets]}" if @verbose
    puts "      → Complexity: #{complexity} (score: #{score})" if @verbose

    complexity
  end

  # ENHANCED OPTIMIZED SCRAPING WITH STRATEGY-BASED APPROACH
  def scrape_venue_optimized(venue_config)
    puts "🚀 Starting optimized scraping for #{venue_config[:name]}..." if @verbose

    # Check for social media only venues
    if is_social_media_only_venue?(venue_config[:url])
      puts "    ⏭️  Skipping social media only venue: #{venue_config[:url]}" if @verbose
      return []
    end

    # Special handling for image-based schedule venues
    if is_image_based_schedule_venue?(venue_config[:name], venue_config[:url])
      return handle_image_based_schedule_venue(venue_config)
    end

    # Special handling for social media redirect venues
    if is_social_media_redirect_venue?(venue_config[:name], venue_config[:url])
      return handle_mitsuki_instagram_redirect(venue_config)
    end

    # Use the new strategy-based approach
    strategy = venue_config[:strategy] || :auto_detect

    case strategy
    when :hybrid_http_first
      puts "  🌐 Using hybrid HTTP-first strategy" if @verbose
      scrape_venue_hybrid_http_first(venue_config)
    when :hybrid_browser
      puts "  🖥️ Using hybrid browser strategy" if @verbose
      scrape_venue_hybrid_browser(venue_config)
    when :cloudflare_bypass
      puts "  🛡️ Using CloudFlare bypass strategy" if @verbose
      scrape_venue_with_cloudflare_bypass(venue_config)
    when :enhanced_date_navigation
      puts "  📅 Using enhanced date navigation strategy" if @verbose
      scrape_venue_with_enhanced_navigation(venue_config)
    when :auto_detect
      # Fallback to complexity-based detection
      complexity = get_cached_complexity(venue_config[:url])

      if complexity == :unknown
        puts "  🔍 Detecting website complexity..." if @verbose
        complexity = detect_website_complexity(venue_config[:url])
      else
        puts "  📋 Using cached complexity: #{complexity}" if @verbose
      end

      case complexity
      when :simple
        puts "  ⚡ Auto-detected: HTTP-first hybrid" if @verbose
        scrape_venue_hybrid_http_first(venue_config)
      when :moderate
        puts "  🌐 Auto-detected: hybrid HTTP-first" if @verbose
        scrape_venue_hybrid_http_first(venue_config)
      when :complex, :very_complex
        puts "  🖥️ Auto-detected: hybrid browser" if @verbose
        scrape_venue_hybrid_browser(venue_config)
      else
        puts "  ❓ Unknown complexity, using hybrid approach" if @verbose
        scrape_venue_hybrid_http_first(venue_config)
      end
    else
      puts "  ⚠️ Unknown strategy, using hybrid approach" if @verbose
      scrape_venue_hybrid_http_first(venue_config)
    end
  end

  def scrape_venue_fast(venue_config)
    # Fast scraping for simple HTML sites
    gigs = []

    with_browser do |browser|
      urls = venue_config[:urls] || [venue_config[:url]]

      urls.each do |url|
        puts "  📄 Fast scraping: #{url}" if @verbose
        browser.get(url)
        sleep(0.5) # Minimal wait for simple sites

        doc = Nokogiri::HTML(browser.page_source)
        page_gigs = extract_gigs_from_page(doc, venue_config)
        gigs.concat(page_gigs)
      end
    end

    gigs
  end

  def scrape_venue_with_js(venue_config)
    # Standard scraping with JavaScript enabled
    scrape_venue(venue_config)
  end

  def scrape_venue_complex(venue_config)
    # Complex scraping with enhanced JavaScript handling
    if venue_config[:name] == "Milkyway"
      gigs = []
      with_browser do |browser|
        gigs = handle_milkyway_date_navigation(browser, venue_config)
      end
      gigs
    else
      scrape_venue(venue_config)
    end
  end

  # NEW HYBRID STRATEGIES FOR HIGH-IMPACT FIXES

  def scrape_venue_hybrid_http_first(venue_config)
    puts "  🌐 Trying HTTP-first hybrid approach..." if @verbose

    # Try HTTP first (3-5x faster)
    gigs = scrape_venue_http_first(venue_config)

    if gigs.nil? || gigs.empty?
      puts "  🔄 HTTP failed, falling back to browser automation..." if @verbose
      gigs = scrape_venue_with_optimized_browser(venue_config)
    else
      puts "  ✅ HTTP success: found #{gigs.count} gigs" if @verbose
    end

    gigs || []
  end

  def scrape_venue_hybrid_browser(venue_config)
    puts "  🖥️ Using optimized browser automation..." if @verbose
    scrape_venue_with_optimized_browser(venue_config)
  end

  def scrape_venue_with_cloudflare_bypass(venue_config)
    puts "  🛡️ Using CloudFlare bypass techniques..." if @verbose

    gigs = []
    with_enhanced_browser do |browser|
      urls = venue_config[:urls] || [venue_config[:url]]

      urls.each do |url|
        begin
          puts "    🔓 Bypassing protection for: #{url}" if @verbose

          # Enhanced headers and behavior to bypass CloudFlare
          browser.execute_script("
            Object.defineProperty(navigator, 'webdriver', {
              get: () => undefined,
            });
          ")

          browser.get(url)

          # Wait for CloudFlare challenge to complete
          sleep(5)

          # Check if we're still on CloudFlare page
          if browser.page_source.include?('Checking your browser') ||
             browser.page_source.include?('cloudflare')
            puts "    ⏳ Waiting for CloudFlare challenge..." if @verbose
            sleep(10) # Additional wait
          end

          doc = Nokogiri::HTML(browser.page_source)
          page_gigs = extract_gigs_from_page_enhanced(doc, venue_config)
          gigs.concat(page_gigs)

          puts "    ✅ Found #{page_gigs.count} gigs after bypass" if @verbose

        rescue => e
          puts "    ❌ Bypass failed for #{url}: #{e.message}" if @verbose
        end
      end
    end

    gigs
  end

  def scrape_venue_with_enhanced_navigation(venue_config)
    puts "  📅 Using enhanced date navigation..." if @verbose

    gigs = []
    with_enhanced_browser do |browser|
      if venue_config[:name] == "Milkyway"
        gigs = handle_milkyway_enhanced_navigation(browser, venue_config)
      else
        # Generic enhanced navigation for other venues
        gigs = handle_enhanced_monthly_coverage(browser, venue_config)
      end
    end

    gigs || []
  end

  def scrape_venue_with_optimized_browser(venue_config)
    gigs = []

    with_optimized_browser do |browser|
      urls = venue_config[:urls] || [venue_config[:url]]

      urls.each do |url|
        begin
          puts "    📄 Optimized browser scraping: #{url}" if @verbose
          browser.get(url)
          sleep(1) # Reduced wait time

          doc = Nokogiri::HTML(browser.page_source)
          page_gigs = extract_gigs_from_page_enhanced(doc, venue_config)
          gigs.concat(page_gigs)

          puts "    ✅ Found #{page_gigs.count} gigs" if @verbose

        rescue => e
          puts "    ❌ Error with #{url}: #{e.message}" if @verbose
        end
      end
    end

    gigs
  end

  def save_results(gigs, filename)
    filepath = Rails.root.join('db', 'data', filename)
    FileUtils.mkdir_p(File.dirname(filepath))

    File.write(filepath, JSON.pretty_generate(gigs))
    puts "📁 Results saved to: #{filepath}"
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

  def with_optimized_browser
    browser = nil
    begin
      browser = create_optimized_browser
      yield browser
    ensure
      browser&.quit
    end
  end

  def with_enhanced_browser
    browser = nil
    begin
      browser = create_enhanced_browser
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
    options.add_argument('--disable-images') # Speed up loading
    options.add_argument('--disable-javascript') unless @enable_js # Default to no JS for speed
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

    # Enhanced timeout and stability options
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-plugins')
    options.add_argument('--disable-web-security')
    options.add_argument('--disable-features=VizDisplayCompositor')
    options.add_argument('--disable-background-timer-throttling')
    options.add_argument('--disable-backgrounding-occluded-windows')

    # Fix for Selenium Manager issues - explicitly set Chrome binary path
    options.binary = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

    # Create webdriver with explicit service configuration
    service = Selenium::WebDriver::Chrome::Service.new(path: '/opt/homebrew/bin/chromedriver')
    browser = Selenium::WebDriver.for :chrome, service: service, options: options

    # 🚀 ADAPTIVE TIMEOUTS based on JS complexity with shorter defaults
    if @enable_js
      browser.manage.timeouts.implicit_wait = 3  # Reduced from 5
      browser.manage.timeouts.page_load = 12     # Reduced from 20
    else
      browser.manage.timeouts.implicit_wait = 1  # Simple HTML sites are fast
      browser.manage.timeouts.page_load = 6      # Reduced from 8
    end

    browser
  rescue => e
    puts "❌ General Chrome browser creation failed: #{e.message}"
    puts "    Falling back to system-managed driver..."
    # Fallback without explicit paths
    browser = Selenium::WebDriver.for :chrome, options: options
    if @enable_js
      browser.manage.timeouts.implicit_wait = 3
      browser.manage.timeouts.page_load = 12
    else
      browser.manage.timeouts.implicit_wait = 1
      browser.manage.timeouts.page_load = 6
    end
    browser
  end

  # Special handling methods for comprehensive monthly coverage

      def handle_milkyway_date_navigation(browser, venue_config)
    puts "  🗓️  Using enhanced Milkyway strategy with iframe detection"
    gigs = []

    # Try the main schedule page
    begin
      browser.get("#{venue_config[:url]}/new/SCHEDULE/")
      sleep(3) # Wait for page to load

      # Check for iframe containing the actual schedule
      puts "    🖼️  Looking for schedule iframe..."
      iframes = browser.find_elements(:tag_name, 'iframe')

      iframe_found = false
      iframes.each_with_index do |iframe, index|
        begin
          src = iframe.attribute('src')
          if src && src.include?('schedule')
            puts "    ✅ Found schedule iframe: #{src}"
            iframe_found = true

            # Switch to iframe and extract content
            browser.switch_to.frame(iframe)
            sleep(3) # Wait for iframe content to load

            iframe_html = browser.page_source
            puts "    📄 Iframe content length: #{iframe_html.length}"

            # Parse iframe content
            iframe_doc = Nokogiri::HTML(iframe_html)
            iframe_gigs = extract_gigs_from_page(iframe_doc, venue_config)

            if iframe_gigs.any?
              puts "    🎯 Found #{iframe_gigs.count} gigs in iframe!"
              gigs.concat(iframe_gigs)
            else
              puts "    ⚠️  No gigs found in iframe, trying alternative selectors..."

              # Try more general selectors for iframe content
              iframe_elements = iframe_doc.css('div, span, p, td, tr, li')
              date_elements = iframe_elements.select do |elem|
                text = elem.text.strip
                text.length > 5 && text.length < 200 &&
                (text.match?(/\d{1,2}\/\d{1,2}/) || text.match?(/\d{4}[-\/]\d{1,2}[-\/]\d{1,2}/) ||
                 (text.include?("月") && text.include?("日")))
              end

              date_elements.each do |elem|
                gig_data = {
                  title: elem.text.strip,
                  date: extract_date_from_any_text(elem.text),
                  venue: venue_config[:name],
                  source_url: src
                }

                if gig_data[:date]
                  gigs << gig_data
                  puts "    + Found potential gig: #{gig_data[:date]} - #{gig_data[:title].first(50)}"
                end
              end
            end

            browser.switch_to.default_content
            break # Found the schedule iframe, no need to check others

          end
        rescue => e
          puts "    ❌ Error with iframe #{index}: #{e.message}"
          browser.switch_to.default_content
        end
      end

      unless iframe_found
        puts "    ⚠️  No schedule iframe found, trying fallback approaches..."

        # Fallback 1: Try direct iframe URLs
        current_date = Date.current
        iframe_urls = [
          "https://shibuyamilkyway.com/schedule/schedule/on/#{current_date.strftime('%Y/%m/%d')}/",
          "https://shibuyamilkyway.com/schedule/schedule/on/",
          "https://shibuyamilkyway.com/schedule/"
        ]

        iframe_urls.each do |iframe_url|
          begin
            puts "    🔗 Trying direct iframe URL: #{iframe_url}"
            browser.get(iframe_url)
            sleep(3)

            iframe_html = browser.page_source
            if iframe_html.length > 1000 # Has substantial content
              iframe_doc = Nokogiri::HTML(iframe_html)
              iframe_gigs = extract_gigs_from_page(iframe_doc, venue_config)

              if iframe_gigs.any?
                puts "    ✅ Found #{iframe_gigs.count} gigs from direct iframe access!"
                gigs.concat(iframe_gigs)
                break
              end
            end
          rescue => e
            puts "    ❌ Direct iframe URL failed: #{e.message}"
          end
        end
      end

      # Original fallback approach if nothing worked
      if gigs.empty?
        puts "    🔄 Attempting original JavaScript date navigation..."

        # Look for clickable date elements using XPath for text matching
        date_selectors = [
          { type: :css, selector: 'button[data-date]' },
          { type: :css, selector: 'a[data-date]' },
          { type: :css, selector: '.date-button' },
          { type: :css, selector: '.calendar-day' },
          { type: :xpath, selector: '//button[contains(text(), "→")]' },
          { type: :xpath, selector: '//button[contains(text(), ">")]' },
          { type: :xpath, selector: '//button[contains(text(), "next")]' },
          { type: :xpath, selector: '//a[contains(text(), "→")]' },
          { type: :xpath, selector: '//a[contains(text(), ">")]' },
          { type: :xpath, selector: '//a[contains(text(), "next")]' },
          { type: :css, selector: '.next-date' },
          { type: :css, selector: '.date-nav' },
          { type: :css, selector: '[class*="next"]' },
          { type: :css, selector: '[class*="forward"]' },
          { type: :css, selector: 'button[onclick*="date"]' },
          { type: :css, selector: 'a[onclick*="date"]' }
        ]

        initial_gig_count = gigs.count
        date_selectors.each do |selector_info|
          begin
            elements = browser.find_elements(selector_info[:type], selector_info[:selector])
            next unless elements.any?

            puts "      Found potential date navigation: #{selector_info[:selector]} (#{elements.count} elements)"

            # Try clicking the first few elements
            elements.first(5).each_with_index do |element, index|
              begin
                # Store current content to detect changes
                current_content = browser.page_source
                current_text = browser.find_element(:tag_name, 'body').text

                puts "        Clicking element #{index + 1}..."
                element.click
                sleep(1.5)

                # Check if content actually changed
                new_content = browser.page_source
                new_text = browser.find_element(:tag_name, 'body').text

                if new_content != current_content || new_text != current_text
                  puts "          ✅ Content changed! Extracting new gigs..."

                  new_gigs = extract_gigs_from_page(Nokogiri::HTML(new_content), venue_config)
                  if new_gigs.any?
                    puts "          Found #{new_gigs.count} new gigs"
                    gigs.concat(new_gigs)
                  else
                    puts "          No gigs found in new content"
                  end
                else
                  puts "          ❌ Content didn't change"
                end

              rescue => e
                puts "          Error clicking element: #{e.message}"
              end
            end

            # If we found interactive elements and got some gigs, that's probably good enough
            if gigs.count > initial_gig_count
              puts "      ✅ Found additional gigs via JavaScript navigation"
              break
            end

          rescue => e
            puts "      Error with selector #{selector_info[:selector]}: #{e.message}"
          end
        end

        # If JavaScript navigation didn't work, try some fallback approaches
        if gigs.count <= initial_gig_count
          puts "    🔧 JavaScript navigation didn't find new content, trying fallbacks..."

          # Try executing JavaScript directly to change dates
          js_attempts = [
            "document.querySelector('[data-date]')?.click();",
            "document.querySelector('.next-date')?.click();",
            "document.querySelector('button:contains(\">\")').click();",
            "if(window.nextDate) window.nextDate();",
            "if(window.changeDate) window.changeDate(new Date());"
          ]

          js_attempts.each do |js_code|
            begin
              puts "      Trying JavaScript: #{js_code}"
              browser.execute_script(js_code)
              sleep(2)

              new_html = browser.page_source
              new_gigs = extract_gigs_from_page(Nokogiri::HTML(new_html), venue_config)

              if new_gigs.count > initial_gig_count
                puts "        ✅ JavaScript execution found new gigs!"
                gigs.concat(new_gigs - gigs[0...initial_gig_count])
                break
              end

            rescue => e
              puts "        JavaScript execution failed: #{e.message}"
            end
          end
        end
      end

    rescue => e
      puts "    Error with Milkyway main page: #{e.message}"

      # Fallback to simple scraping
      puts "    💫 Falling back to simple page scraping..."
      begin
        browser.get(venue_config[:url])
        sleep(3)

        page_html = browser.page_source
        doc = Nokogiri::HTML(page_html)
        fallback_gigs = extract_gigs_from_page(doc, venue_config)
        gigs.concat(fallback_gigs)

        puts "    Found #{fallback_gigs.count} gigs from fallback"
      rescue => fallback_error
        puts "    Fallback also failed: #{fallback_error.message}"
      end
    end

    gigs
  end

  def handle_monthly_coverage(browser, venue_config)
    puts "  📅 Using enhanced monthly coverage"
    gigs = []

    # Standard URLs
    urls_to_try = venue_config[:urls] || [venue_config[:url]]

    # Add monthly/date-specific URLs
    current_month = Date.current
    next_month = current_month.next_month

    additional_urls = [
      # Different date format attempts
      "#{venue_config[:url]}/#{current_month.strftime('%Y/%m')}/",
      "#{venue_config[:url]}/schedule/#{current_month.strftime('%Y/%m')}/",
      "#{venue_config[:url]}/events/#{current_month.strftime('%Y/%m')}/",
      "#{venue_config[:url]}/#{next_month.strftime('%Y/%m')}/",
      "#{venue_config[:url]}/schedule/#{next_month.strftime('%Y/%m')}/",
      "#{venue_config[:url]}/events/#{next_month.strftime('%Y/%m')}/",
      # Query parameter attempts
      "#{venue_config[:url]}?month=#{current_month.strftime('%Y-%m')}",
      "#{venue_config[:url]}?date=#{current_month.strftime('%Y-%m')}",
      "#{venue_config[:url]}?year=#{current_month.year}&month=#{current_month.month}"
    ]

    all_urls = (urls_to_try + additional_urls).uniq

    all_urls.each do |url|
      puts "    Trying enhanced URL: #{url}"

      begin
        browser.get(url)
        sleep(1) # Reduced from 3 for speed

        page_html = browser.page_source
        doc = Nokogiri::HTML(page_html)
        venue_gigs = extract_gigs_from_page(doc, venue_config)
        gigs.concat(venue_gigs)

        puts "      Found #{venue_gigs.count} gigs"

        # Look for "next page" or "more events" links
        next_page_selectors = [
          'a[class*="next"]', 'a[class*="more"]', '.pagination a',
          'button[class*="next"]', 'button[class*="more"]',
          'a:contains("次")', 'a:contains("more")', 'a:contains("Next")'
        ]

        next_page_selectors.each do |selector|
          begin
            next_links = browser.find_elements(:css, selector)
            next_links.first(2).each do |link|
              link.click
              sleep(2)

              page_html = browser.page_source
              doc = Nokogiri::HTML(page_html)
              more_gigs = extract_gigs_from_page(doc, venue_config)

              if more_gigs.any?
                puts "        Found #{more_gigs.count} additional gigs via pagination"
                gigs.concat(more_gigs)
              end
            end
          rescue => e
            # Continue with next selector
          end
        end

      rescue => e
        puts "      Error with URL #{url}: #{e.message}"
      end
    end

    gigs
  end

  # ENHANCED SPECIAL HANDLING METHODS FOR HIGH-IMPACT FIXES

  def handle_milkyway_enhanced_navigation(browser, venue_config)
    puts "  🗓️ Using ENHANCED Milkyway strategy with expanded date coverage"
    gigs = []

    # Try multiple approaches for comprehensive coverage
    approaches = [
      { name: "Main Schedule Page", url: "#{venue_config[:url]}/new/SCHEDULE/" },
      { name: "Root Page", url: venue_config[:url] },
      { name: "Schedule Directory", url: "#{venue_config[:url]}/schedule/" }
    ]

    approaches.each do |approach|
      puts "    🎯 Trying #{approach[:name]}: #{approach[:url]}"

      begin
        browser.get(approach[:url])
        sleep(3)

        # Look for iframes first
        iframes = browser.find_elements(:tag_name, 'iframe')
        iframe_processed = false

        iframes.each_with_index do |iframe, index|
          begin
            src = iframe.attribute('src')
            if src && (src.include?('schedule') || src.include?('calendar'))
              puts "      🖼️ Processing schedule iframe: #{src}"

              browser.switch_to.frame(iframe)
              sleep(3)

              # Extract from iframe with enhanced selectors
              iframe_html = browser.page_source
              iframe_doc = Nokogiri::HTML(iframe_html)

              # Try multiple extraction strategies
              iframe_gigs = extract_gigs_with_multiple_strategies(iframe_doc, venue_config, src)

              if iframe_gigs.any?
                puts "      ✅ Found #{iframe_gigs.count} gigs in iframe"
                gigs.concat(iframe_gigs)
                iframe_processed = true
              end

              browser.switch_to.default_content
            end
          rescue => iframe_error
            puts "      ⚠️ Iframe processing failed: #{iframe_error.message}"
            browser.switch_to.default_content rescue nil
          end
        end

        # If no iframe success, try main page content
        unless iframe_processed
          puts "      📄 Extracting from main page content"
          main_doc = Nokogiri::HTML(browser.page_source)
          main_gigs = extract_gigs_with_multiple_strategies(main_doc, venue_config, approach[:url])

          if main_gigs.any?
            puts "      ✅ Found #{main_gigs.count} gigs from main content"
            gigs.concat(main_gigs)
          end
        end

      rescue => approach_error
        puts "      ❌ #{approach[:name]} failed: #{approach_error.message}"
      end
    end

    # Deduplicate and return
    unique_gigs = gigs.uniq { |gig| [gig[:title], gig[:date], gig[:venue]] }
    puts "    📊 Total unique gigs found: #{unique_gigs.count}"
    unique_gigs
  end

  def handle_monthly_coverage_with_bypass(browser, venue_config)
    puts "  🛡️ Using monthly coverage with CloudFlare bypass for Den-atsu"
    gigs = []

    # Enhanced bypass techniques
    browser.execute_script("
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined,
      });
      Object.defineProperty(navigator, 'plugins', {
        get: () => [1, 2, 3, 4, 5],
      });
      Object.defineProperty(navigator, 'languages', {
        get: () => ['en-US', 'en'],
      });
    ")

    # Try multiple URL patterns with bypass
    current_month = Date.current
    next_month = current_month.next_month

    url_patterns = [
      venue_config[:url],
      "#{venue_config[:url]}/schedulelist/",
      "#{venue_config[:url]}/schedule/",
      "#{venue_config[:url]}/live/",
      "#{venue_config[:url]}/event/",
      "#{venue_config[:url]}/#{current_month.strftime('%Y/%m')}/",
      "#{venue_config[:url]}/#{next_month.strftime('%Y/%m')}/"
    ]

    url_patterns.each do |url|
      begin
        puts "    🔓 Bypassing protection for: #{url}"

        browser.get(url)
        sleep(8) # Longer wait for CloudFlare

        # Check for CloudFlare challenge
        page_source = browser.page_source
        if page_source.include?('Checking your browser') ||
           page_source.include?('cloudflare') ||
           page_source.include?('Just a moment')
          puts "      ⏳ Detected CloudFlare challenge, waiting..."
          sleep(15) # Extended wait
          page_source = browser.page_source
        end

        # Extract gigs if we got through
        if page_source.length > 1000 # Reasonable content length
          doc = Nokogiri::HTML(page_source)
          page_gigs = extract_gigs_with_multiple_strategies(doc, venue_config, url)

          if page_gigs.any?
            puts "      ✅ Found #{page_gigs.count} gigs after bypass"
            gigs.concat(page_gigs)
          else
            puts "      ⚠️ No gigs found despite successful bypass"
          end
        else
          puts "      ❌ Still blocked or minimal content"
        end

      rescue => bypass_error
        puts "      ❌ Bypass failed for #{url}: #{bypass_error.message}"
      end
    end

    gigs.uniq { |gig| [gig[:title], gig[:date], gig[:venue]] }
  end

  def handle_enhanced_monthly_coverage(browser, venue_config)
    puts "  📅 Using enhanced monthly coverage with expanded date range"
    gigs = []

    # Generate URLs for next 2 months (expanded coverage)
    current_month = Date.current
    months_to_check = [current_month, current_month.next_month, current_month.next_month.next_month]

    base_urls = venue_config[:urls] || [venue_config[:url]]

    all_urls = []
    base_urls.each do |base_url|
      all_urls << base_url

      months_to_check.each do |month|
        # Multiple date format patterns
        date_patterns = [
          "/#{month.strftime('%Y/%m')}/",
          "/#{month.strftime('%Y-%m')}/",
          "/schedule/#{month.strftime('%Y/%m')}/",
          "/events/#{month.strftime('%Y/%m')}/",
          "/calendar/#{month.strftime('%Y/%m')}/",
          "?month=#{month.strftime('%Y-%m')}",
          "?date=#{month.strftime('%Y-%m')}",
          "?year=#{month.year}&month=#{month.month}"
        ]

        date_patterns.each do |pattern|
          all_urls << "#{base_url.chomp('/')}#{pattern}"
        end
      end
    end

    all_urls.uniq.each do |url|
      begin
        puts "    📅 Enhanced URL: #{url}"
        browser.get(url)
        sleep(2) # Optimized wait time

        doc = Nokogiri::HTML(browser.page_source)
        page_gigs = extract_gigs_with_multiple_strategies(doc, venue_config, url)

        if page_gigs.any?
          puts "      ✅ Found #{page_gigs.count} gigs"
          gigs.concat(page_gigs)
        end

      rescue => url_error
        puts "      ⚠️ URL failed: #{url_error.message}"
      end
    end

    gigs.uniq { |gig| [gig[:title], gig[:date], gig[:venue]] }
  end

    def extract_gigs_with_multiple_strategies(doc, venue_config, source_url)
    gigs = []

    # Strategy 1: Use configured selectors
    strategy1_gigs = extract_gigs_from_page_enhanced(doc, venue_config)
    gigs.concat(strategy1_gigs)

    # Strategy 2: Aggressive text pattern matching
    all_text_elements = doc.css('div, span, p, td, li, h1, h2, h3, h4, h5, h6, a, section, article')
    all_text_elements.each do |element|
      text = element.text.strip
      next if text.length < 5 || text.length > 500 # Increased max length

      if contains_date_pattern?(text)
        # Extract date and create gig entry
        extracted_date = extract_date_from_any_text(text)
        if extracted_date
          # Clean up title by removing date patterns
          clean_title = text.gsub(/\d{4}[-\/]\d{1,2}[-\/]\d{1,2}/, '').strip
          clean_title = text if clean_title.length < 3 # Keep original if cleaning removes too much

          gig = {
            title: clean_text(clean_title),
            date: extracted_date,
            venue: venue_config[:name],
            source_url: source_url,
            extraction_strategy: 'text_pattern_matching'
          }
          gigs << gig
        end
      end
    end

    # Strategy 3: Enhanced table-based extraction
    tables = doc.css('table')
    tables.each do |table|
      rows = table.css('tr')
      rows.each do |row|
        cells = row.css('td, th')
        next if cells.length < 1

        # Look for date in any cell
        cells.each_with_index do |cell, index|
          if contains_date_pattern?(cell.text)
            extracted_date = extract_date_from_any_text(cell.text)
            if extracted_date
              # Use other cells for title/info
              other_cells = cells.select.with_index { |_, i| i != index }
              title = other_cells.map(&:text).join(' ').strip

              # If no good title from other cells, use the date cell content
              if title.length < 3
                title = cell.text.strip
              end

              if title.length > 3
                gig = {
                  title: clean_text(title),
                  date: extracted_date,
                  venue: venue_config[:name],
                  source_url: source_url,
                  extraction_strategy: 'table_based'
                }
                gigs << gig
              end
            end
          end
        end
      end
    end

    # Strategy 4: Link-based extraction (many venues use links for events)
    links = doc.css('a[href]')
    links.each do |link|
      href = link.attribute('href')&.value
      text = link.text.strip

      next if text.length < 5 || text.length > 300

      # Look for event-related URLs or date patterns in link text
      if (href && (href.include?('event') || href.include?('schedule') || href.include?('live'))) ||
         contains_date_pattern?(text)

        extracted_date = extract_date_from_any_text(text)
        if extracted_date
          gig = {
            title: clean_text(text),
            date: extracted_date,
            venue: venue_config[:name],
            source_url: source_url,
            extraction_strategy: 'link_based'
          }
          gigs << gig
        end
      end
    end

    # Strategy 5: JSON-LD structured data extraction
    json_scripts = doc.css('script[type="application/ld+json"]')
    json_scripts.each do |script|
      begin
        data = JSON.parse(script.content)
        events = []

        # Handle different JSON-LD structures
        if data.is_a?(Array)
          events = data.select { |item| item['@type'] == 'Event' }
        elsif data['@type'] == 'Event'
          events = [data]
        elsif data['@graph']
          events = data['@graph'].select { |item| item['@type'] == 'Event' }
        end

        events.each do |event|
          if event['name'] && event['startDate']
            gig = {
              title: clean_text(event['name']),
              date: Date.parse(event['startDate']).strftime('%Y-%m-%d'),
              venue: venue_config[:name],
              source_url: source_url,
              extraction_strategy: 'json_ld'
            }
            gigs << gig
          end
        end
      rescue JSON::ParserError, Date::Error
        # Skip invalid JSON or dates
      end
    end

    gigs.uniq { |gig| [gig[:title], gig[:date], gig[:venue]] }
  end

  public

  # Quick speed test method
  def quick_speed_test
    puts "🚀 QUICK SPEED & MILKYWAY FIX TEST"
    puts "="*50

    start_time = Time.current

    # Test with optimized settings
    result = test_proven_venues(verbose: true)

    end_time = Time.current
    duration = (end_time - start_time).round(2)

    puts "\n" + "="*50
    puts "SPEED TEST RESULTS:"
    puts "⏱️  Total time: #{duration} seconds"
    puts "🏆 Successful venues: #{result[:successful_venues]}/#{PROVEN_VENUES.count}"
    puts "📊 Total gigs found: #{result[:total_gigs]}"
    puts "⚡ Average time per venue: #{(duration / PROVEN_VENUES.count).round(2)} seconds"

    if result[:failed_venues].any?
      puts "\n❌ Failed venues:"
      result[:failed_venues].each { |failure| puts "  • #{failure[:venue]} - #{failure[:reason]}" }
    end

    puts "\n🎯 OPTIMIZATIONS APPLIED:"
    puts "  • JavaScript disabled by default (enabled only when needed)"
    puts "  • Images disabled for faster loading"
    puts "  • Reduced timeouts (15s page load, 3s implicit wait)"
    puts "  • Automatic website complexity detection"
    puts "  • Fixed Milkyway CSS selectors (XPath for text matching)"
    puts "  • Reduced sleep times throughout"

    result
  end

  # 🚀 ULTRA-FAST SPEED TEST - All optimizations combined
  def ultra_speed_test
    puts "🚀 ULTRA-FAST SPEED TEST - ALL OPTIMIZATIONS!"
    puts "="*60
    puts "🎯 Combining: Parallel + HTTP-first + Caching + Adaptive timeouts"
    puts "="*60

    start_time = Time.current

    # Test with all optimizations
    result = test_proven_venues_parallel(verbose: true)

    end_time = Time.current
    duration = (end_time - start_time).round(2)
    old_duration = 466.66 # Previous sequential time

    puts "\n" + "="*60
    puts "🏁 ULTRA-FAST RESULTS COMPARISON:"
    puts "="*60
    puts "⚡ New parallel time: #{duration} seconds"
    puts "🐌 Old sequential time: #{old_duration} seconds"
    puts "🚀 Speed improvement: #{((old_duration / duration)).round(1)}x FASTER!"
    puts "💾 Cache hits: #{@website_complexity_cache.count} venues cached"
    puts "🏆 Success rate: #{result[:successful_venues]}/#{PROVEN_VENUES.count} (#{((result[:successful_venues].to_f / PROVEN_VENUES.count) * 100).round(1)}%)"
    puts "📊 Total gigs: #{result[:total_gigs]}"
    puts "⚡ Gigs per second: #{(result[:total_gigs].to_f / duration).round(2)}"

    if result[:failed_venues].any?
      puts "\n❌ Failed venues:"
      result[:failed_venues].each { |failure| puts "  • #{failure[:venue]} - #{failure[:reason]}" }
    end

    puts "\n🎯 ALL OPTIMIZATIONS ACTIVE:"
    puts "  ✅ Parallel processing (#{@max_parallel_venues} threads)"
    puts "  ✅ HTTP-first approach for simple sites"
    puts "  ✅ Persistent complexity caching"
    puts "  ✅ Adaptive timeouts (1-5s vs 3-10s)"
    puts "  ✅ JavaScript auto-detection"
    puts "  ✅ Image loading disabled"
    puts "  ✅ Smart fallback strategies"

    puts "\n🎉 Ready for production scaling!"

    result
  end

  # 🚀 ULTRA-FAST N+1 SCALING TEST
  def ultra_fast_n_plus_one_test(candidate_limit = 5)
    puts "🚀 ULTRA-FAST N+1 SCALING TEST!"
    puts "="*60
    puts "🎯 Testing #{PROVEN_VENUES.count} proven + #{candidate_limit} candidate venues with ALL optimizations"
    puts "="*60

    start_time = Time.current
    all_gigs = []
    successful_venues = 0
    failed_venues = []
    proven_successful = 0
    candidate_successful = 0
    total_gigs = 0

    # Combine proven venues with candidate venues
    candidate_venues = get_candidate_venues(candidate_limit)
    puts "📋 Selected #{candidate_venues.count} candidate venues for testing"

    # Convert candidate venues to our config format
    candidate_configs = candidate_venues.map do |venue|
      {
        name: venue.name,
        url: venue.website,
        selectors: get_general_selectors
      }
    end

    # Combine all venues for parallel processing
    all_venue_configs = PROVEN_VENUES + candidate_configs
    total_venues = all_venue_configs.count

    puts "⚡ Processing #{total_venues} venues (#{PROVEN_VENUES.count} proven + #{candidate_configs.count} candidates) with #{@max_parallel_venues} parallel threads..."

    # Process all venues in parallel
    results = Concurrent::ThreadPoolExecutor.new(
      min_threads: 1,
      max_threads: @max_parallel_venues,
      max_queue: 0, # Unlimited queue
      fallback_policy: :caller_runs
    ).tap do |executor|

      venue_futures = all_venue_configs.map do |venue_config|
        Concurrent::Future.execute(executor: executor) do
          thread_id = Thread.current.object_id

          is_proven = PROVEN_VENUES.any? { |v| v[:name] == venue_config[:name] }
          venue_type = is_proven ? "PROVEN" : "CANDIDATE"

          puts "🔄 [#{venue_type}] [Thread #{thread_id}] Starting #{venue_config[:name]}..." if @verbose

          result = scrape_venue_ultra_fast(venue_config)

          if result[:success]
            gigs = result[:gigs]
            puts "✅ [#{venue_type}] [#{venue_config[:name]}] SUCCESS: #{gigs.count} gigs" if @verbose
            successful_venues += 1
            total_gigs += gigs.count

            if is_proven
              proven_successful += 1
            else
              candidate_successful += 1
            end

            all_gigs.concat(gigs)
          else
            puts "❌ [#{venue_type}] [#{venue_config[:name]}] #{result[:reason]}" if @verbose
            failed_venues << { venue: venue_config[:name], reason: result[:reason] }
          end
        end
      end

      # Wait for all futures to complete with timeout
      begin
        venue_futures.each { |future| future.wait!(300) } # 5 minute timeout per venue
      rescue Concurrent::TimeoutError => e
        puts "⚠️ Some venues timed out, shutting down gracefully..." if @verbose
      end

      # Graceful shutdown
      executor.shutdown
      unless executor.wait_for_termination(60) # 1 minute shutdown timeout
        puts "⚠️ Forcing executor shutdown..." if @verbose
        executor.kill
      end
    end

    end_time = Time.current
    duration = (end_time - start_time).round(2)

    # Save results
    save_results(all_gigs, "ultra_fast_n_plus_one_test.json")
    save_complexity_cache

    puts "\n" + "="*60
    puts "🏁 ULTRA-FAST N+1 SCALING RESULTS!"
    puts "="*60
    puts "⚡ Total time: #{duration} seconds"
    puts "🏆 Total successful venues: #{successful_venues}/#{total_venues}"
    puts "  📊 Proven venues: #{proven_successful}/#{PROVEN_VENUES.count}"
    puts "  🎯 Candidate venues: #{candidate_successful}/#{candidate_configs.count}"
    puts "📊 Total gigs found: #{all_gigs.count}"
    puts "🚀 Average time per venue: #{(duration / total_venues).round(2)} seconds"
    puts "⚡ Gigs per second: #{(all_gigs.count.to_f / duration).round(2)}"
    puts "💾 Complexity cache entries: #{@website_complexity_cache.count}"

    # Show scaling projection
    if duration < 300 # Under 5 minutes
      projected_100_time = (100 * duration / total_venues / 60).round(2)
      puts "\n🌍 SCALING PROJECTION:"
      puts "📈 100 venues estimated time: #{projected_100_time} minutes"
      puts "🚀 1000 venues estimated time: #{(projected_100_time * 10).round(1)} minutes"
    end

    if failed_venues.any?
      puts "\n❌ FAILED VENUES:"

      if failed_venues.any?
        puts "  🔴 Proven venue failures:"
        failed_venues.each { |failure| puts "    • #{failure[:venue]} - #{failure[:reason]}" }
      end
    end

    # Show successful new venues
    if candidate_successful > 0
      puts "\n🎉 NEW SUCCESSFUL VENUES DISCOVERED:"
      # Find successful candidates from the processed results
      successful_candidate_names = []

      # Since we don't have structured result tracking, we'll show discovered ones
      candidate_configs.each do |config|
        # Check if this candidate was successful (rough approximation)
        if all_gigs.any? { |gig| gig[:venue] == config[:name] }
          gig_count = all_gigs.count { |gig| gig[:venue] == config[:name] }
          puts "  ✅ #{config[:name]} - #{gig_count} gigs"
        end
      end
    end

    puts "\n🎯 ALL OPTIMIZATIONS ACTIVE:"
    puts "  ✅ Parallel processing (#{@max_parallel_venues} threads)"
    puts "  ✅ HTTP-first approach for simple sites"
    puts "  ✅ Persistent complexity caching"
    puts "  ✅ Adaptive timeouts"
    puts "  ✅ Smart venue filtering"
    puts "  ✅ Proven + candidate venue mixing"

    {
      total_successful: successful_venues,
      proven_successful: proven_successful,
      candidate_successful: candidate_successful,
      total_gigs: all_gigs.count,
      duration: duration,
      failed_venues: failed_venues,
      gigs: all_gigs
    }
  end

  # 🔧 HTML extraction methods (public for HTTP-first approach)
  def extract_gigs_from_page(doc, venue_config)
    gigs = []
    selectors = venue_config[:selectors]

    # Find gig elements
    gig_elements = []
    selectors[:gigs].split(', ').each do |selector|
      elements = doc.css(selector.strip)
      gig_elements.concat(elements.to_a)
    end

    gig_elements.each do |element|
      gig_data = extract_gig_data(element, selectors, venue_config[:name], venue_config[:url])

      if gig_data[:title] && gig_data[:date]
        gigs << gig_data
      end
    end

    gigs
  end

  def extract_gig_data(element, selectors, venue_name, source_url)
    gig = {
      title: extract_text_by_selectors(element, selectors[:title]),
      date: extract_and_parse_date(element, selectors[:date]),
      time: extract_text_by_selectors(element, selectors[:time]),
      artists: extract_text_by_selectors(element, selectors[:artists]),
      venue: venue_name,
      source_url: source_url
    }

    # Clean up data
    gig[:title] = clean_text(gig[:title])
    gig[:artists] = clean_text(gig[:artists])

    gig
  end

  def extract_text_by_selectors(element, selectors)
    return nil unless selectors

    selectors.split(', ').each do |selector|
      found_element = element.at_css(selector.strip)
      if found_element && found_element.text.present?
        return found_element.text.strip
      end
    end

    nil
  end

  def extract_and_parse_date(element, selectors)
    date_text = extract_text_by_selectors(element, selectors)
    return nil unless date_text

    # Try to parse the date
    parsed_date = parse_date_from_text(date_text)
    parsed_date&.strftime('%Y-%m-%d')
  end

  def parse_date_from_text(text)
    return nil unless text

    text = text.strip

    # Enhanced date patterns for Japanese venues
    date_patterns = [
      # Standard international formats
      /(\d{4})[.\-\/](\d{1,2})[.\-\/](\d{1,2})/,  # 2025-06-10, 2025.6.10, 2025/6/10
      /(\d{1,2})[.\-\/](\d{1,2})[.\-\/](\d{4})/,  # 10-06-2025, 6.10.2025
      /(\d{4})\.(\d{1,2})\.(\d{1,2})/,           # 2025.6.10

      # Japanese formats
      /(\d{4})年(\d{1,2})月(\d{1,2})日/,          # 2025年6月10日
      /(\d{1,2})月(\d{1,2})日/,                    # 6月10日
      /(\d{1,2})\/(\d{1,2})\(.*?\)/,             # 6/10(tue)

      # Compact formats common in venue listings
      /(\d{1,2})\.(\d{1,2})\([^)]+\)/,           # 6.10(火)
      /(\d{1,2})\/(\d{1,2})/,                    # 6/10
      /(\d{2})(\d{2})/,                          # 0610 (MMDD)

      # Day-first formats
      /(\d{1,2})\s*[\-\.\/]\s*(\d{1,2})/,       # 10-6, 10.6, 10/6

      # Year-month-day without separators
      /(\d{4})(\d{2})(\d{2})/,                   # 20250610

      # Month day patterns with text
      /(\d{1,2})\s*(月|\/)\s*(\d{1,2})/,         # 6月10, 6/10

      # Single digit dates with context
      /(?:^|\s)(\d{1,2})\s*$/ # Single digits (day only, assume current month)
    ]

    date_patterns.each do |pattern|
      if match = text.match(pattern)
        begin
          if pattern.to_s.include?('年') && pattern.to_s.include?('月')
            # Full Japanese format: 2025年6月10日
            year = match[1].to_i
            month = match[2].to_i
            day = match[3].to_i
            return Date.new(year, month, day)
          elsif pattern.to_s.include?('月')
            # Japanese month format: 6月10日
            month = match[1].to_i
            day = match[2].to_i
            year = Date.current.year
            return Date.new(year, month, day)
          elsif match.captures.length == 3 && match[1].length == 4
            # Year first format: 2025-06-10
            year = match[1].to_i
            month = match[2].to_i
            day = match[3].to_i
            return Date.new(year, month, day)
          elsif match.captures.length == 3 && match[1].length == 8
            # YYYYMMDD format: 20250610
            year_str = match[1]
            year = year_str[0..3].to_i
            month = year_str[4..5].to_i
            day = year_str[6..7].to_i
            return Date.new(year, month, day)
          elsif match.captures.length == 2
            # Two-part dates
            first = match[1].to_i
            second = match[2].to_i
            year = Date.current.year

            # Determine if it's MM/DD or DD/MM based on values
            if first > 12
              # First number > 12, must be day
              day = first
              month = second
            elsif second > 12
              # Second number > 12, must be day
              month = first
              day = second
            else
              # Both <= 12, assume MM/DD (common in Japan)
              month = first
              day = second
            end

            return Date.new(year, month, day) if month.between?(1, 12) && day.between?(1, 31)
          elsif match.captures.length == 1
            # Single number - assume it's the day of current month
            day = match[1].to_i
            month = Date.current.month
            year = Date.current.year
            return Date.new(year, month, day) if day.between?(1, 31)
          end
        rescue => e
          # Continue to next pattern if this one fails
          puts "    🔍 Date parsing failed for pattern #{pattern}: #{e.message}" if @verbose
        end
      end
    end

    # Try natural language parsing (handles "today", "tomorrow", etc.)
    begin
      # Clean up common Japanese date indicators
      cleaned_text = text.gsub(/[（）()【】\[\]]/, ' ')  # Remove brackets
                         .gsub(/[本日|今日|明日]/, '')     # Remove "today/tomorrow"
                         .gsub(/[開催|予定|から]/, '')     # Remove "held/scheduled/from"
                         .strip

      Date.parse(cleaned_text) if cleaned_text.present?
    rescue
      nil
    end
  end

  # 🎯 SMART VENUE TARGETING - Based on 100-venue analysis results
  def smart_targeted_test(limit = 50)
    puts "🎯 SMART VENUE TARGETING TEST (#{limit} venues)"
    puts "📊 Using patterns from successful venues: ACB Hall, Crocodile, SAMURAI"
    puts "=" * 70

    # Get baseline from proven venues first
    baseline_result = test_proven_venues
    puts "\n📊 BASELINE: #{baseline_result[:successful_venues]} proven venues, #{baseline_result[:total_gigs]} gigs"

    # Get smartly filtered candidate venues
    smart_candidates = get_candidate_venues(limit)
    puts "\n🎯 Testing #{smart_candidates.count} SMART-FILTERED venues..."
    puts "🔍 Selection criteria: Live houses, active websites, similar to successful venues"

    all_gigs = baseline_result[:gigs].dup
    successful_venues = baseline_result[:successful_venues]
    failed_venues = baseline_result[:failed_venues].dup
    venues_to_delete = []
    smart_success_count = 0

    smart_candidates.each_with_index do |venue, index|
      puts "\n" + "-"*60
      puts "TESTING SMART CANDIDATE #{index + 1}/#{smart_candidates.count}: #{venue.name}"
      puts "URL: #{venue.website}"
      puts "Similarity Score: #{venue.try(:similarity_score) || 'N/A'}"
      puts "-"*60

      begin
        if website_accessible?(venue.website)
          venue_config = {
            name: venue.name,
            url: venue.website,
            selectors: get_enhanced_selectors_for_venue(venue)
          }

          # Use intelligent complexity detection
          gigs = scrape_venue_optimized(venue_config)

          if gigs && gigs.any?
            valid_gigs = filter_valid_gigs(gigs)

            if valid_gigs.any?
              puts "✅ SUCCESS: Found #{valid_gigs.count} valid gigs for #{venue.name}"

              # 💾 Save to database
              db_result = save_gigs_to_database(valid_gigs, venue.name)
              puts "    💾 Database: #{db_result[:saved]} saved, #{db_result[:skipped]} skipped" if @verbose

              all_gigs.concat(valid_gigs)
              successful_venues += 1
              smart_success_count += 1

              # Show examples
              puts "📅 Sample gigs:"
              valid_gigs.first(2).each do |gig|
                puts "    ✓ #{gig[:date]} - #{gig[:title]}"
              end

            else
              puts "⚠️  NO VALID GIGS: #{venue.name} - found #{gigs.count} gigs but none were valid/current"
              failed_venues << { venue: venue.name, url: venue.website, reason: "No valid current gigs" }
            end
          else
            puts "⚠️  NO GIGS: #{venue.name}"
            failed_venues << { venue: venue.name, url: venue.website, reason: "No gigs found" }
          end
        else
          puts "❌ DEAD WEBSITE: #{venue.name} - marking for deletion"
          venues_to_delete << venue
          failed_venues << { venue: venue.name, url: venue.website, reason: "Dead website - will be deleted" }
        end

      rescue => e
        puts "❌ ERROR: #{venue.name} - #{e.message}"
        failed_venues << { venue: venue.name, url: venue.website, reason: e.message }
      end

      sleep(2) # Rate limiting
    end

    # Clean up dead venues safely
    if venues_to_delete.any?
      puts "\n🗑️  CLEANING UP #{venues_to_delete.count} DEAD VENUES:"
      venues_to_delete.each do |venue|
        puts "  Processing: #{venue.name}"
        begin
          venue.destroy!
        rescue ActiveRecord::InvalidForeignKey => e
          puts "    ⚠️  Cannot delete #{venue.name} - has existing gigs. Updating website to NULL instead."
          venue.update!(website: nil)
        rescue => e
          puts "    ❌ Error processing #{venue.name}: #{e.message}"
        end
      end
    end

    # Save results
    save_results(all_gigs, "smart_targeted_test.json")

    # Calculate smart targeting success rate
    smart_success_rate = smart_candidates.any? ? (smart_success_count.to_f / smart_candidates.count * 100).round(1) : 0
    baseline_success_rate = 3.2  # From our 100-venue analysis
    improvement = smart_success_rate - baseline_success_rate

    puts "\n" + "="*70
    puts "SMART TARGETING TEST COMPLETE!"
    puts "="*70
    puts "✅ Total successful venues: #{successful_venues}"
    puts "📊 Total gigs found: #{all_gigs.count}"
    puts "🆕 New venues discovered: #{smart_success_count}"
    puts "🎯 Smart targeting success rate: #{smart_success_rate}% (vs #{baseline_success_rate}% baseline)"
    puts "📈 Improvement: #{improvement > 0 ? '+' : ''}#{improvement.round(1)} percentage points"
    puts "🗑️  Deleted dead venues: #{venues_to_delete.count}"

    if improvement > 0
      puts "\n🎉 SMART TARGETING SUCCESSFUL! Better than random venue selection."
    else
      puts "\n⚠️  Smart targeting didn't improve success rate - need better filtering criteria."
    end

    {
      total_successful_venues: successful_venues,
      total_gigs: all_gigs.count,
      smart_discoveries: smart_success_count,
      smart_success_rate: smart_success_rate,
      improvement: improvement,
      failed_venues: failed_venues,
      deleted_venues: venues_to_delete.count
    }
  end

  # 🎯 Enhanced scraping method for better venue targeting
  def scrape_venue_enhanced(venue_config)
    puts "\n🎯 Scraping #{venue_config[:name]}..."
    gigs = []

    begin
      browser = setup_browser

      # First find the schedule page
      schedule_url = find_schedule_page(browser, venue_config)
      if schedule_url
        # Now try to extract gigs from the schedule page
        browser.get(schedule_url)
        sleep(3)

        # Try multiple extraction strategies
        gigs = extract_gigs_with_multiple_strategies(
          Nokogiri::HTML(browser.page_source),
          venue_config,
          schedule_url
        )
      end

    rescue => e
      puts "  ❌ Error scraping #{venue_config[:name]}: #{e.message}"
    ensure
      browser&.quit
    end

    gigs
  end

  # 📊 Production monitoring and health check
  def production_health_check
    puts "\n🏥 PRODUCTION HEALTH CHECK"
    puts "="*50

    # Memory status
    memory_report = @memory_monitor.memory_report
    puts "💾 Memory Status:"
    puts "   Start: #{memory_report[:start]}MB"
    puts "   Current: #{memory_report[:current]}MB"
    puts "   Peak: #{memory_report[:peak]}MB"
    puts "   Increase: #{memory_report[:increase]}MB"

    # Database connection status
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      db_status = "✅ Connected"
    rescue => e
      db_status = "❌ Error: #{e.message}"
    end
    puts "🗄️ Database: #{db_status}"

    # Connection pool status
    pool = ActiveRecord::Base.connection_pool
    puts "🏊 Connection Pool:"
    puts "   Size: #{pool.size}"
    puts "   Checked out: #{pool.stat[:busy]}"
    puts "   Available: #{pool.size - pool.stat[:busy]}"

    # Circuit breaker status
    puts "🔄 Circuit Breaker: Active with #{@circuit_breaker.instance_variable_get(:@failure_counts).size} tracked venues"

    # Cache status
    puts "💾 Caches:"
    puts "   Complexity cache: #{@website_complexity_cache.size} entries"
    puts "   Venue blacklist: #{@venue_blacklist.values.flatten.size} venues"

    puts "="*50
    puts "🎯 System ready for production scraping"
  end

  private

  def setup_browser
    create_enhanced_browser
  end

  def scrape_venue(venue_config)
    gigs = []

    with_browser do |browser|
      if venue_config[:special_handling]
        gigs = send("handle_#{venue_config[:special_handling]}", browser, venue_config)
      else
        # Standard scraping
        urls_to_try = venue_config[:urls] || [venue_config[:url]]

        urls_to_try.each do |url|
          puts "  Trying URL: #{url}"

          begin
            browser.get(url)
            sleep(1) # Reduced from 3 for speed

            page_html = browser.page_source
            doc = Nokogiri::HTML(page_html)

            venue_gigs = extract_gigs_from_page(doc, venue_config)
            gigs.concat(venue_gigs)

            puts "    Found #{venue_gigs.count} gigs on this page"

          rescue => e
            puts "    Error with URL #{url}: #{e.message}"
          end
        end
      end
    end

    puts "🔗 Deduplicating gigs: #{gigs.count} raw -> #{gigs.uniq { |gig| [gig[:title], gig[:date]] }.count} unique"
    gigs.uniq { |gig| [gig[:title], gig[:date]] }
  end

  # 🚫 Intelligent venue blacklisting
  def load_venue_blacklist
    cache_file = Rails.root.join('tmp', 'venue_blacklist.json')

    if File.exist?(cache_file)
      begin
        JSON.parse(File.read(cache_file), symbolize_names: true)
      rescue
        { timeout_venues: [], dead_venues: [], no_content_venues: [] }
      end
    else
      { timeout_venues: [], dead_venues: [], no_content_venues: [] }
    end
  end

  def save_venue_blacklist(blacklist)
    cache_file = Rails.root.join('tmp', 'venue_blacklist.json')
    FileUtils.mkdir_p(File.dirname(cache_file))
    File.write(cache_file, JSON.pretty_generate(blacklist))
    puts "🚫 Venue blacklist updated: #{cache_file}" if @verbose
  end

  def is_venue_blacklisted?(venue_name, url)
    # Never blacklist proven venues
    proven_venue_names = PROVEN_VENUES.map { |v| v[:name] }
    if proven_venue_names.include?(venue_name)
      return false
    end

    blacklist = load_venue_blacklist

    blacklisted = blacklist[:timeout_venues].include?(venue_name) ||
                  blacklist[:dead_venues].include?(venue_name) ||
                  blacklist[:no_content_venues].include?(venue_name)

    if blacklisted
      puts "  🚫 [#{venue_name}] Skipping blacklisted venue" if @verbose
    end

    blacklisted
  end

  def add_to_blacklist(venue_name, reason)
    # Never blacklist proven venues
    proven_venue_names = PROVEN_VENUES.map { |v| v[:name] }
    if proven_venue_names.include?(venue_name)
      puts "  ⚠️  [#{venue_name}] NOT blacklisting proven venue (reason: #{reason})" if @verbose
      return
    end

    blacklist = load_venue_blacklist

    case reason
    when /timeout/i
      blacklist[:timeout_venues] << venue_name unless blacklist[:timeout_venues].include?(venue_name)
    when /no gigs/i, /no content/i
      blacklist[:no_content_venues] << venue_name unless blacklist[:no_content_venues].include?(venue_name)
    else
      blacklist[:dead_venues] << venue_name unless blacklist[:dead_venues].include?(venue_name)
    end

    save_venue_blacklist(blacklist)
  end

  # 🎯 IMPROVED: Smart failure tracking and blacklisting
  def record_venue_failure(venue_name, failure_type)
    @venue_failures ||= {}
    @venue_failures[venue_name] ||= { timeout: 0, error: 0, no_gigs: 0 }
    @venue_failures[venue_name][failure_type.to_sym] += 1
  end

  def should_blacklist_venue?(venue_name)
    return false unless @venue_failures && @venue_failures[venue_name]

    failures = @venue_failures[venue_name]

    # Blacklist after 3 timeouts or 5 general errors
    failures[:timeout] >= 3 || failures[:error] >= 5
  end

  def reset_venue_failures
    @venue_failures = {}
  end

  # 💾 Database integration - save gigs to database with connection management
  def save_gigs_to_database(gigs, venue_name)
    return unless gigs&.any?

    @db_connection_manager.with_connection do
      venue = find_or_create_venue(venue_name)
      saved_count = 0
      skipped_count = 0

      gigs.each do |gig_data|
        begin
          # Check if gig already exists
          existing_gig = Gig.find_by(
            venue: venue,
            date: parse_date_for_db(gig_data[:date])
          )

          if existing_gig
            skipped_count += 1
            next
          end

          # Create new gig
          gig = Gig.new(
            venue: venue,
            date: parse_date_for_db(gig_data[:date]),
            open_time: parse_time_for_db(gig_data[:time]) || "19:00", # Default time
            start_time: parse_time_for_db(gig_data[:time], add_30_minutes: true) || "19:30",
            price: parse_price_for_db(gig_data),
            user: find_default_user
          )

          if gig.save
            # Create bands and bookings for this gig
            create_bands_for_gig(gig, gig_data)

            saved_count += 1
            puts "    💾 Saved gig: #{gig.date} - #{gig_data[:title]}" if @verbose
          else
            puts "    ⚠️ Failed to save gig: #{gig.errors.full_messages.join(', ')}" if @verbose
          end

        rescue => e
          puts "    ❌ Error saving gig: #{e.message}" if @verbose
        end
      end

      puts "    📊 Database: #{saved_count} saved, #{skipped_count} skipped" if @verbose
      { saved: saved_count, skipped: skipped_count }
    end
  end

  def create_bands_for_gig(gig, gig_data)
    # Extract band names from title and artists fields
    band_names = extract_band_names(gig_data)

    band_names.each do |band_name|
      next if band_name.blank?

      # Find or create band
      band = find_or_create_band(band_name)

      # Create booking if it doesn't exist
      unless Booking.exists?(gig: gig, band: band)
        Booking.create!(gig: gig, band: band)
        puts "      🎤 Associated band: #{band.name}" if @verbose
      end
    end
  end

  def extract_band_names(gig_data)
    band_names = []

    # Extract from artists field first (most reliable)
    if gig_data[:artists].present?
      artists_text = clean_text(gig_data[:artists])
      extracted_artists = extract_artists_from_text(artists_text)
      band_names.concat(extracted_artists)
    end

    # Extract from title if no artists found, but be much more careful
    if band_names.empty? && gig_data[:title].present?
      title_text = clean_text(gig_data[:title])
      extracted_from_title = extract_artists_from_title(title_text)
      band_names.concat(extracted_from_title)
    end

    # Filter out obvious non-band names
    band_names = filter_valid_band_names(band_names)

    # Default band name if nothing meaningful found
    if band_names.empty?
      band_names = ["Live Performance"]
    end

    band_names.uniq.first(3) # Limit to 3 bands max
  end

  def extract_artists_from_text(text)
    return [] unless text.present?

    # Clean up the text first
    cleaned_text = preprocess_artist_text(text)
    return [] if cleaned_text.blank?

    # Split on common separators
    separators = [' / ', ' × ', ' & ', ' and ', '、', '・', ' + ', ' with ', ' feat. ', ' featuring ']
    band_names = [cleaned_text]

    separators.each do |separator|
      band_names = band_names.flat_map { |name| name.split(separator) }
    end

    # Clean and validate each name
    band_names.map(&:strip)
              .reject(&:blank?)
              .map { |name| clean_artist_name(name) }
              .reject(&:blank?)
  end

  def extract_artists_from_title(title_text)
    return [] unless title_text.present?

    # Much more aggressive filtering for titles since they often contain event info
    return [] if is_event_description?(title_text)

    # Try to extract artist names from structured title formats
    extracted = extract_from_structured_title(title_text)
    return extracted if extracted.any?

    # If no structured format found, be very conservative
    return [] if title_text.length > 100 # Too long, likely event description
    return [] if title_text.match?(/\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/) # Contains dates
    return [] if title_text.match?(/open|start|door|ticket|price|¥|\$|admission/i) # Event details

    # Only proceed if it looks like a simple artist name
    if looks_like_artist_name?(title_text)
      [clean_artist_name(title_text)].reject(&:blank?)
    else
      []
    end
  end

  def preprocess_artist_text(text)
    # Remove common prefixes that indicate event info, not artist names
    text = text.gsub(/^(出演|出演者|アーティスト|artist|performers?|featuring|guest|special|live|show)[:：\s]+/i, '')

    # Remove DJ prefixes when they're clearly event descriptions
    text = text.gsub(/^●?DJ[:：]\s*/i, '') if text.match?(/●?DJ[:：]\s*[A-Z\s]+\(/i)

    # Remove venue/event info in parentheses at the end
    text = text.gsub(/\s*\([^)]*(?:from|@|at|venue|club|bar|hall)\s*[^)]*\)\s*$/i, '')

    # Remove time/date info
    text = text.gsub(/\s*\d{1,2}:\d{2}\s*/, ' ')
    text = text.gsub(/\s*\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}\s*/, ' ')

    text.strip
  end

  def clean_artist_name(name)
    return '' unless name.present?

    # Remove common non-artist prefixes/suffixes
    name = name.gsub(/^(DJ|dj)\s+/i, '') unless name.match?(/^DJ\s+[A-Z][a-z]/i) # Keep "DJ Something" but remove "DJ ●"
    name = name.gsub(/\s+(live|show|event|performance|set)$/i, '')
    name = name.gsub(/^(the\s+)?live\s+/i, '')
    name = name.gsub(/\s*\([^)]*(?:live|show|event|performance|set|tour|release)\s*[^)]*\)\s*/i, '')

    # Remove venue/location info in parentheses
    name = name.gsub(/\s*\([^)]*(?:from|@|at|venue|club|bar|hall|tokyo|japan|uk|us|london|berlin)\s*[^)]*\)\s*/i, '')

    # Remove obvious event markers
    name = name.gsub(/\s*[●○■□▲△▼▽◆◇★☆]\s*/, ' ')
    name = name.gsub(/\s*[-–—]\s*(live|show|event|performance|tour|release).*$/i, '')

    # Clean up whitespace
    name = name.gsub(/\s+/, ' ').strip

    name
  end

  def is_event_description?(text)
    # Check for obvious event description patterns
    event_patterns = [
      /\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/, # Dates
      /\d{1,2}[\/\-\.]\d{1,2}\s*\([月火水木金土日]\)/, # Japanese date format
      /anniversary|birthday|release|tour|festival|party|night|session/i,
      /open\s*\d{1,2}:\d{2}|start\s*\d{1,2}:\d{2}|door\s*\d{1,2}:\d{2}/i,
      /ticket|price|admission|advance|door|¥\d+|\$\d+/i,
      /presents?|invites?|vs\.?|battle|competition/i,
      /live\s+(show|event|performance|concert)|show\s+(live|event)/i,
      /\d+(st|nd|rd|th)\s+(anniversary|birthday)/i
    ]

    event_patterns.any? { |pattern| text.match?(pattern) }
  end

    def extract_from_structured_title(title)
    artists = []

    # Pattern: "Artist Name Live" or "Artist Name Show"
    match = title.match(/^([^●○■□▲△▼▽◆◇★☆]+?)\s+(live|show|concert)$/i)
    if match
      artist = match[1].strip
      artists << clean_artist_name(artist) if looks_like_artist_name?(artist)
    end

    # Pattern: "Live: Artist Name" or "Show: Artist Name"
    match = title.match(/^(live|show|concert)[:：]\s*(.+)$/i)
    if match
      artist = match[2].strip
      artists << clean_artist_name(artist) if looks_like_artist_name?(artist)
    end

    # Pattern: "Artist Name ● Other Info" (take only the artist part)
    match = title.match(/^([^●○■□▲△▼▽◆◇★☆]+?)\s*[●○■□▲△▼▽◆◇★☆]/i)
    if match
      artist = match[1].strip
      artists << clean_artist_name(artist) if looks_like_artist_name?(artist)
    end

    artists.reject(&:blank?)
  end

  def looks_like_artist_name?(text)
    return false unless text.present?
    return false if text.length < 2 || text.length > 50

    # Should not contain obvious event markers
    return false if text.match?(/\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/)
    return false if text.match?(/open|start|door|ticket|price|¥|\$|admission/i)
    return false if text.match?(/anniversary|birthday|release|tour|festival|party|night|session/i)
    return false if text.match?(/live\s+(show|event|performance)|show\s+(live|event)/i)

    # Should not be mostly numbers or symbols
    return false if text.gsub(/[a-zA-Zひらがなカタカナ漢字]/, '').length > text.length * 0.5

    # Should contain some letters
    return false unless text.match?(/[a-zA-Zひらがなカタカナ漢字]/)

    true
  end

  def filter_valid_band_names(band_names)
    band_names.select do |name|
      next false if name.blank?
      next false if name.length < 2 || name.length > 100

      # Filter out obvious non-band patterns
      next false if name.match?(/^(live|show|event|performance|concert|festival|party|session|night|open|start|door)$/i)
      next false if name.match?(/^\d+$/) # Just numbers
      next false if name.match?(/^[●○■□▲△▼▽◆◇★☆\s]+$/) # Just symbols
      next false if name.match?(/\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/) # Contains dates
      next false if name.match?(/ticket|price|admission|¥\d+|\$\d+/i) # Pricing info

      # Must contain some actual letters/characters
      next false unless name.match?(/[a-zA-Zひらがなカタカナ漢字]/)

      true
    end
  end

  def find_or_create_band(band_name)
    # Clean band name
    clean_name = clean_text(band_name)
    return nil if clean_name.blank?

    # Try to find existing band
    band = Band.find_by(name: clean_name)
    return band if band

    # Determine genre using Spotify API first, fallback to name-based detection
    genre = determine_genre_with_spotify(clean_name)

    # Create new band with defaults
    Band.create!(
      name: clean_name,
      genre: genre,
      hometown: "Tokyo",
      email: "info@#{clean_name.downcase.gsub(/[^a-z0-9]/, '')}.com"
    )
  end

    def determine_genre_with_spotify(band_name)
    # First try Spotify API for accurate genre detection
    begin
      spotify_service = SpotifyService.new
      genre_info = spotify_service.get_artist_genre_info(band_name)

      if genre_info && genre_info[:confidence] > 75 && genre_info[:primary_genre] != "Unknown"
        puts "    🎵 Spotify genre: #{genre_info[:primary_genre]} (#{genre_info[:confidence]}% confidence)" if @verbose
        return genre_info[:primary_genre]
      end
    rescue => e
      puts "    ⚠️ Spotify API error: #{e.message}" if @verbose
      Rails.logger.warn "Spotify genre detection failed for #{band_name}: #{e.message}"
    end

    # Fallback to name-based detection
    puts "    🔤 Using name-based genre detection" if @verbose
    determine_genre_from_name(band_name)
  end

  def determine_genre_from_name(band_name)
    # Enhanced genre detection based on band name patterns and context
    name_lower = band_name.downcase.strip

    # Return Unknown for obviously non-musical content
    return "Unknown" if name_lower.match?(/live|show|event|performance|concert|festival|party|presents|featuring|vs\.|&|open mic|jam session|workshop|talk|lecture|exhibition/)

    # Electronic/DJ genres
    return "Electronic" if name_lower.match?(/\bdj\b|electronic|techno|house|ambient|edm|dubstep|trance|drum.?n.?bass|dnb|breakbeat|garage|minimal|acid|rave/)

    # Jazz and related
    return "Jazz" if name_lower.match?(/jazz|swing|blues|bebop|fusion|bossa.?nova|latin.?jazz|smooth.?jazz|big.?band|quartet|quintet|trio.*jazz/)

    # Hip-Hop and Rap
    return "Hip-Hop" if name_lower.match?(/hip.?hop|rap|mc\b|rapper|freestyle|trap|drill|grime/)

    # Classical and orchestral
    return "Classical" if name_lower.match?(/orchestra|symphony|classical|chamber|philharmonic|quartet.*classical|concerto|opera|baroque/)

    # Folk and acoustic
    return "Folk" if name_lower.match?(/folk|acoustic|singer.?songwriter|americana|country|bluegrass|celtic/)

    # Indie and alternative
    return "Indie" if name_lower.match?(/indie|underground|alternative|alt.?rock|shoegaze|dream.?pop|lo.?fi/)

    # Punk and hardcore
    return "Punk" if name_lower.match?(/punk|hardcore|emo|screamo|post.?punk|ska.?punk/)

    # Metal genres
    return "Metal" if name_lower.match?(/metal|death|black.*metal|doom|sludge|grind|core$|metalcore|deathcore/)

    # Pop and mainstream
    return "Pop" if name_lower.match?(/pop|idol|j.?pop|k.?pop|mainstream|commercial/)

    # Reggae and related
    return "Reggae" if name_lower.match?(/reggae|ska|dub|rastafari|jamaica/)

    # World music
    return "World" if name_lower.match?(/world|ethnic|traditional|cultural|african|latin|asian|middle.?eastern/)

    # Experimental and avant-garde
    return "Experimental" if name_lower.match?(/experimental|avant.?garde|noise|drone|ambient|soundscape|improvisation/)

    # R&B and Soul
    return "R&B" if name_lower.match?(/r&b|soul|funk|motown|neo.?soul|contemporary.?r&b/)

    # If band name is very short or generic, likely Unknown
    return "Unknown" if name_lower.length < 3 || name_lower.match?(/^(band|group|artist|music|sound|live|show)s?$/)

    # Japanese-specific patterns
    return "J-Rock" if name_lower.match?(/j.?rock|japanese.*rock|visual.?kei/)
    return "J-Pop" if name_lower.match?(/j.?pop|japanese.*pop/)

    # Only classify as Rock if there are actual rock-related keywords
    return "Rock" if name_lower.match?(/rock|guitar|band.*rock|classic.*rock|hard.*rock|soft.*rock|prog|progressive/)

    # Default to Unknown instead of Rock for unclassifiable bands
    "Unknown"
  end

  def find_or_create_venue(venue_name)
    # Try to find existing venue by name
    venue = Venue.find_by(name: venue_name)
    return venue if venue

    # Create new venue if not found
    venue = Venue.create!(
      name: venue_name,
      address: "Tokyo", # Default address
      email: "info@#{venue_name.downcase.gsub(/[^a-z0-9]/, '')}.com",
      neighborhood: "Tokyo",
      details: "Scraped venue - details to be updated"
    )

    puts "    🏢 Created new venue: #{venue_name}" if @verbose
    venue
  end

  def find_default_user
    @default_user ||= User.first || User.create!(
      email: "scraper@example.com",
      username: "scraper",
      address: "Tokyo",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def parse_date_for_db(date_string)
    return nil unless date_string

    if date_string.is_a?(Date)
      return date_string
    end

    begin
      Date.parse(date_string.to_s)
    rescue => e
      puts "    ⚠️ Could not parse date: #{date_string}" if @verbose
      nil
    end
  end

  def parse_time_for_db(time_string, add_30_minutes: false)
    return nil unless time_string

    # Clean up common time formats
    time_clean = time_string.to_s.strip
                           .gsub(/[開始時間|OPEN|START|時|分]/, '')
                           .gsub(/\./, ':')

    # Extract time patterns like "18:30", "18.30", "6:30PM"
    if time_match = time_clean.match(/(\d{1,2})[:.](\d{2})/)
      hour = time_match[1].to_i
      minute = time_match[2].to_i

      # Add 30 minutes for start time
      if add_30_minutes
        minute += 30
        if minute >= 60
          hour += 1
          minute -= 60
        end
      end

      return sprintf("%02d:%02d", hour, minute)
    end

    nil
  end

  def parse_price_for_db(gig_data)
    # Try to extract price from various fields
    price_sources = [gig_data[:price], gig_data[:title], gig_data[:artists]].compact

    price_sources.each do |source|
      # Look for yen amounts like "¥3000", "3000円", "3,000円"
      if price_match = source.to_s.match(/[¥￥]?(\d{1,2}[,.]?\d{3})[円]?/)
        return price_match[1].gsub(/[,.]/, '')
      end
    end

    "3000" # Default price
  end

  # 🎯 VENUE SCORING SYSTEM - Prioritize high-performing venues
  def get_prioritized_venues(limit = nil)
    # Score venues based on:
    # 1. Number of gigs (higher = better)
    # 2. Recent activity (more recent = better)
    # 3. Website quality (real domain = better)
    # 4. Avoid social media only venues

    venues = Venue.where.not(website: [nil, ''])
                  .where.not("website ILIKE '%facebook%'")
                  .where.not("website ILIKE '%instagram%'")
                  .where.not("website ILIKE '%twitter%'")
                  .where.not("website ILIKE '%tiktok%'")
                  .left_joins(:gigs)
                  .group('venues.id')
                  .select('venues.*, COUNT(gigs.id) as gig_count, MAX(gigs.date) as latest_gig')
                  .order('gig_count DESC, latest_gig DESC NULLS LAST')

    venues = venues.limit(limit) if limit
    venues
  end

  # 🎯 SMART VENUE SELECTION - Focus on proven performers
  def get_high_value_venues(limit = 200)
    # Get venues with proven track record
    high_performers = Venue.joins(:gigs)
                           .where.not(website: [nil, ''])
                           .where.not("website ILIKE '%facebook%'")
                           .where.not("website ILIKE '%instagram%'")
                           .group('venues.id')
                           .having('COUNT(gigs.id) >= 3') # At least 3 gigs
                           .order('COUNT(gigs.id) DESC')
                           .limit(limit)

    puts "🎯 Selected #{high_performers.count} high-value venues (3+ gigs each)" if @verbose
    high_performers
  end

  # 🔄 RETRY LOGIC - Give temporarily failed venues another chance
  def should_retry_venue?(venue_name)
    return false unless @venue_failures && @venue_failures[venue_name]

    failures = @venue_failures[venue_name]

    # Retry venues with only 1-2 failures (might be temporary issues)
    (failures[:timeout] <= 2 && failures[:error] <= 2)
  end

end
