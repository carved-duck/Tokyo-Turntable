namespace :venues do
  desc "🔍 Discover venues with PDF schedule opportunities"
  task discover_pdf_schedules: :environment do
    puts "🔍 PDF VENUE DISCOVERY & TESTING"
    puts "=" * 50

    discoverer = PdfVenueDiscoverer.new
    discoverer.run_discovery
  end
end

class PdfVenueDiscoverer
  def initialize
    @pdf_venues_found = []
    @tested_venues = 0
    @successful_extractions = 0
  end

  def run_discovery
    puts "\n📋 PHASE 1: PDF VENUE SCANNING"
    puts "-" * 30
    scan_for_pdf_venues

    puts "\n📋 PHASE 2: PDF EXTRACTION TESTING"
    puts "-" * 30
    test_pdf_extraction

    puts "\n📊 DISCOVERY RESULTS"
    puts "=" * 30
    puts "🔍 Venues scanned: #{@tested_venues}"
    puts "📄 PDF venues found: #{@pdf_venues_found.length}"
    puts "✅ Successful extractions: #{@successful_extractions}"

    if @pdf_venues_found.any?
      puts "\n🎯 TOP PDF VENUE OPPORTUNITIES:"
      @pdf_venues_found.first(5).each do |venue_info|
        puts "   📄 #{venue_info[:name]} (#{venue_info[:confidence]}% confidence)"
        puts "      #{venue_info[:website]}"
        puts "      PDF type: #{venue_info[:pdf_indicators].join(', ')}"
      end
    end
  end

  private

  def scan_for_pdf_venues
    # Target venues that are likely to have PDF schedules
    candidate_venues = Venue.where.not(website: [nil, ''])
                            .where("website NOT LIKE '%facebook%'")
                            .where("website NOT LIKE '%instagram%'")
                            .where("website NOT LIKE '%twitter%'")
                            .where("name LIKE '%hall%' OR name LIKE '%center%' OR name LIKE '%theater%' OR name LIKE '%theatre%' OR name LIKE '%arena%'")
                            .limit(100)

    puts "🎯 Scanning #{candidate_venues.count} high-potential venues..."

    candidate_venues.each do |venue|
      @tested_venues += 1
      puts "   [#{@tested_venues}/#{candidate_venues.count}] Checking: #{venue.name}"

      pdf_info = analyze_venue_for_pdfs(venue)
      if pdf_info[:has_pdfs]
        @pdf_venues_found << pdf_info
        puts "      ✅ PDF opportunity found! (#{pdf_info[:confidence]}% confidence)"
      end
    end

    puts "\n📄 Found #{@pdf_venues_found.length} venues with PDF potential"
  end

  def analyze_venue_for_pdfs(venue)
    result = {
      name: venue.name,
      website: venue.website,
      has_pdfs: false,
      confidence: 0,
      pdf_indicators: [],
      pdf_links: []
    }

    begin
      response = HTTParty.get(venue.website, {
        timeout: 8,
        headers: {
          'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      })

      if response.success?
        content = response.body.downcase
        doc = Nokogiri::HTML(response.body)

        # Look for PDF links
        pdf_links = doc.css('a[href*=".pdf"], a[href$=".pdf"]')

        pdf_links.each do |link|
          href = link['href']
          link_text = link.text.strip.downcase

          # Score PDF relevance
          relevance_score = score_pdf_link(href, link_text, content)

          if relevance_score > 5
            result[:pdf_links] << {
              url: resolve_pdf_url(href, venue.website),
              text: link_text,
              score: relevance_score
            }
          end
        end

        # Check for schedule-related PDF indicators
        pdf_indicators = [
          'schedule.pdf', 'calendar.pdf', 'events.pdf', 'lineup.pdf',
          'monthly.pdf', 'weekly.pdf', 'flyer.pdf', 'program.pdf',
          'concert.pdf', 'live.pdf', 'show.pdf', 'performance.pdf'
        ]

        pdf_indicators.each do |indicator|
          if content.include?(indicator)
            result[:pdf_indicators] << indicator
            result[:confidence] += 15
          end
        end

        # Bonus points for venue characteristics
        if venue.name.match?/(hall|center|theater|theatre|arena)/i
          result[:confidence] += 10
        end

        # Check if site mentions PDF schedules in text
        schedule_pdf_patterns = [
          /schedule.*pdf/i,
          /pdf.*schedule/i,
          /download.*schedule/i,
          /calendar.*pdf/i,
          /event.*pdf/i
        ]

        schedule_pdf_patterns.each do |pattern|
          if content.match?(pattern)
            result[:confidence] += 8
            result[:pdf_indicators] << 'mentioned_in_text'
          end
        end

        result[:has_pdfs] = result[:pdf_links].any? || result[:confidence] > 20
      end

    rescue => e
      # Skip problematic venues
    end

    result
  end

  def score_pdf_link(href, link_text, page_content)
    score = 0
    combined_text = "#{href} #{link_text}".downcase

    # High relevance terms
    high_terms = %w[schedule calendar event live concert show program lineup flyer monthly weekly]
    high_terms.each { |term| score += 10 if combined_text.include?(term) }

    # Medium relevance terms
    medium_terms = %w[info news update announcement]
    medium_terms.each { |term| score += 5 if combined_text.include?(term) }

    # Date patterns in filename
    score += 8 if href.match?(/\d{4}[-_]\d{2}/) || href.match?(/\d{2}[-_]\d{4}/)

    # Penalty for non-schedule content
    negative_terms = %w[menu food drink map access contact about staff history]
    negative_terms.each { |term| score -= 3 if combined_text.include?(term) }

    [score, 0].max
  end

  def resolve_pdf_url(href, base_url)
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
    rescue
      href
    end
  end

  def test_pdf_extraction
    return if @pdf_venues_found.empty?

    puts "🧪 Testing PDF extraction on discovered venues..."

    @pdf_venues_found.first(3).each do |venue_info|
      next if venue_info[:pdf_links].empty?

      puts "\n   📄 Testing: #{venue_info[:name]}"

      venue_info[:pdf_links].first(2).each do |pdf_link|
        puts "      🔗 Testing PDF: #{File.basename(pdf_link[:url])}"

        begin
          # Test PDF extraction without full download
          test_result = test_pdf_accessibility(pdf_link[:url])

          if test_result[:accessible]
            puts "         ✅ PDF accessible (#{test_result[:size_kb]}KB)"
            @successful_extractions += 1

            # Quick content check
            if test_result[:likely_schedule]
              puts "         🎯 Likely contains schedule content!"
            end
          else
            puts "         ❌ PDF not accessible"
          end

        rescue => e
          puts "         ⚠️  Error testing PDF: #{e.message}"
        end
      end
    end

    # Save results for future use
    save_pdf_discovery_results
  end

  def test_pdf_accessibility(pdf_url)
    result = { accessible: false, size_kb: 0, likely_schedule: false }

    begin
      # Head request to check accessibility and size
      response = HTTParty.head(pdf_url, timeout: 5)

      if response.success?
        result[:accessible] = true

        # Get file size
        if response.headers['content-length']
          result[:size_kb] = response.headers['content-length'].to_i / 1024
        end

        # Check if it's actually a PDF
        content_type = response.headers['content-type']
        if content_type && content_type.include?('pdf')
          result[:likely_schedule] = true if pdf_url.match?(/schedule|calendar|event|live|concert/i)
        end
      end
    rescue => e
      # PDF not accessible
    end

    result
  end

  def save_pdf_discovery_results
    results = {
      discovery_date: Date.current.to_s,
      venues_scanned: @tested_venues,
      pdf_venues_found: @pdf_venues_found.length,
      successful_extractions: @successful_extractions,
      venues: @pdf_venues_found
    }

    File.write(
      Rails.root.join('tmp', 'pdf_venue_discovery_results.json'),
      JSON.pretty_generate(results)
    )

    puts "\n💾 Saved discovery results to tmp/pdf_venue_discovery_results.json"
  end
end
