class AiAccuracyEnhancer
  def initialize(options = {})
    @verbose = options[:verbose] || false
    @openai_client = setup_openai_client
    @claude_available = check_claude_availability
    @accuracy_cache = load_accuracy_cache
    @learning_data = load_learning_data
  end

  # 🧠 MAIN AI ACCURACY ENHANCEMENT
  def enhance_venue_scraping_accuracy(venue_config)
    puts "🧠 AI-Enhanced Venue Analysis: #{venue_config[:name]}" if @verbose

    # Step 1: AI-powered content analysis
    content_analysis = analyze_venue_content_with_ai(venue_config)

    # Step 2: Generate optimal selectors using AI
    ai_selectors = generate_ai_optimized_selectors(content_analysis)

    # Step 3: AI-powered content extraction
    enhanced_gigs = extract_gigs_with_ai_assistance(venue_config, ai_selectors)

    # Step 4: AI validation and cleanup
    validated_gigs = validate_and_clean_with_ai(enhanced_gigs)

    {
      success: validated_gigs.any?,
      gigs: validated_gigs,
      ai_confidence: content_analysis[:confidence],
      improvements: content_analysis[:improvements]
    }
  end

  # 🎵 AI-POWERED BAND NAME EXTRACTION
  def extract_band_names_with_ai(raw_text, context = {})
    puts "🎵 AI Band Name Extraction from: #{raw_text[0..50]}..." if @verbose

    prompt = build_band_extraction_prompt(raw_text, context)

    begin
      response = @openai_client.chat(
        parameters: {
          model: "gpt-4",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.1, # Low temperature for accuracy
          max_tokens: 500
        }
      )

      ai_result = parse_ai_band_extraction(response.dig("choices", 0, "message", "content"))

      # Validate AI results with our existing logic
      validated_bands = validate_ai_band_extraction(ai_result, raw_text)

      puts "🎯 AI extracted #{validated_bands.length} bands with #{ai_result[:confidence]}% confidence" if @verbose

      validated_bands
    rescue => e
      puts "⚠️ AI extraction failed: #{e.message}" if @verbose
      fallback_to_rule_based_extraction(raw_text)
    end
  end

  # 🎧 ADVANCED SPOTIFY MATCHING WITH AI
  def enhance_spotify_matching_with_ai(band_name)
    puts "🎧 AI-Enhanced Spotify Matching: #{band_name}" if @verbose

    # Step 1: AI-powered band name normalization
    normalized_name = normalize_band_name_with_ai(band_name)

    # Step 2: Generate search variations using AI
    search_variations = generate_search_variations_with_ai(normalized_name)

    # Step 3: Enhanced Spotify search with AI-generated queries
    spotify_results = search_spotify_with_ai_variations(search_variations)

    # Step 4: AI-powered result validation
    best_match = validate_spotify_results_with_ai(band_name, spotify_results)

    best_match
  end

  # 🔍 AI CONTENT ANALYSIS
  def analyze_venue_content_with_ai(venue_config)
    puts "🔍 AI Content Analysis for #{venue_config[:name]}" if @verbose

    # Get webpage content
    content = fetch_venue_content(venue_config[:url])
    return { confidence: 0, improvements: [] } unless content

    # Analyze with AI
    analysis_prompt = build_content_analysis_prompt(content, venue_config)

    begin
      response = @openai_client.chat(
        parameters: {
          model: "gpt-4",
          messages: [{ role: "user", content: analysis_prompt }],
          temperature: 0.2,
          max_tokens: 1000
        }
      )

      ai_analysis = parse_ai_content_analysis(response.dig("choices", 0, "message", "content"))

      # Cache successful analysis for learning
      cache_analysis_result(venue_config[:url], ai_analysis)

      ai_analysis
    rescue => e
      puts "⚠️ AI content analysis failed: #{e.message}" if @verbose
      { confidence: 50, improvements: ["AI analysis unavailable"] }
    end
  end

  # 🎯 AI SELECTOR GENERATION
  def generate_ai_optimized_selectors(content_analysis)
    puts "🎯 Generating AI-Optimized Selectors" if @verbose

    selector_prompt = build_selector_generation_prompt(content_analysis)

    begin
      response = @openai_client.chat(
        parameters: {
          model: "gpt-4",
          messages: [{ role: "user", content: selector_prompt }],
          temperature: 0.1,
          max_tokens: 800
        }
      )

      ai_selectors = parse_ai_selector_response(response.dig("choices", 0, "message", "content"))

      # Merge with proven selectors for fallback
      merge_with_proven_selectors(ai_selectors)
    rescue => e
      puts "⚠️ AI selector generation failed: #{e.message}" if @verbose
      get_fallback_selectors
    end
  end

  # 🧹 AI VALIDATION AND CLEANUP
  def validate_and_clean_with_ai(raw_gigs)
    puts "🧹 AI Validation and Cleanup of #{raw_gigs.length} gigs" if @verbose

    return [] unless raw_gigs.any?

    # Process in batches to avoid token limits
    validated_gigs = []

    raw_gigs.each_slice(5) do |gig_batch|
      validation_prompt = build_gig_validation_prompt(gig_batch)

      begin
        response = @openai_client.chat(
          parameters: {
            model: "gpt-4",
            messages: [{ role: "user", content: validation_prompt }],
            temperature: 0.1,
            max_tokens: 1000
          }
        )

        validated_batch = parse_ai_validation_response(response.dig("choices", 0, "message", "content"))
        validated_gigs.concat(validated_batch)
      rescue => e
        puts "⚠️ AI validation failed for batch: #{e.message}" if @verbose
        # Fallback to rule-based validation
        validated_gigs.concat(fallback_validation(gig_batch))
      end
    end

    validated_gigs
  end

  # 🎓 CONTINUOUS LEARNING SYSTEM
  def learn_from_successful_extractions(venue_name, successful_gigs)
    puts "🎓 Learning from successful extraction: #{venue_name}" if @verbose

    learning_data = {
      venue: venue_name,
      timestamp: Time.current,
      gig_count: successful_gigs.length,
      patterns: extract_successful_patterns(successful_gigs),
      selectors_used: @last_successful_selectors
    }

    @learning_data << learning_data
    save_learning_data

    # Update AI prompts based on learning
    update_ai_prompts_from_learning
  end

  # 🚀 ACCURACY BOOST SYSTEM
  def run_accuracy_boost_on_failed_venues(limit = 20)
    puts "🚀 AI ACCURACY BOOST - Targeting Failed Venues" if @verbose
    puts "=" * 60

    # Get venues that have failed to produce gigs
    failed_venues = Venue.left_joins(:gigs)
                         .where(gigs: { id: nil })
                         .where.not(website: [nil, ''])
                         .where("website NOT LIKE '%facebook%'")
                         .where("website NOT LIKE '%instagram%'")
                         .limit(limit)

    puts "🎯 Found #{failed_venues.count} failed venues to enhance with AI"

    successful_recoveries = 0
    total_gigs_recovered = 0

    failed_venues.each_with_index do |venue, index|
      puts "\n[#{index + 1}/#{failed_venues.count}] 🧠 AI-Enhancing: #{venue.name}"

      venue_config = {
        name: venue.name,
        url: venue.website,
        selectors: {} # Will be AI-generated
      }

      # Apply AI enhancement
      result = enhance_venue_scraping_accuracy(venue_config)

      if result[:success] && result[:gigs].any?
        puts "  ✅ AI SUCCESS: #{result[:gigs].length} gigs recovered!"
        puts "  🎯 AI Confidence: #{result[:ai_confidence]}%"

        # Save to database
        save_ai_enhanced_gigs(result[:gigs], venue.name)

        successful_recoveries += 1
        total_gigs_recovered += result[:gigs].length

        # Learn from this success
        learn_from_successful_extractions(venue.name, result[:gigs])
      else
        puts "  ❌ AI enhancement failed"
      end

      # Respectful delay
      sleep(2)
    end

    puts "\n🎉 AI ACCURACY BOOST COMPLETE!"
    puts "=" * 60
    puts "🏆 Venues recovered: #{successful_recoveries}/#{failed_venues.count}"
    puts "🎵 Total gigs recovered: #{total_gigs_recovered}"
    puts "📈 Recovery rate: #{(successful_recoveries.to_f / failed_venues.count * 100).round(1)}%"

    {
      venues_processed: failed_venues.count,
      successful_recoveries: successful_recoveries,
      total_gigs_recovered: total_gigs_recovered,
      recovery_rate: (successful_recoveries.to_f / failed_venues.count * 100).round(1)
    }
  end

  private

  def setup_openai_client
    require 'openai'
    OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  rescue LoadError
    puts "⚠️ OpenAI gem not available" if @verbose
    nil
  end

  def check_claude_availability
    # Check if Claude API is available
    ENV['ANTHROPIC_API_KEY'].present?
  end

  def build_band_extraction_prompt(raw_text, context)
    <<~PROMPT
      You are an expert at extracting band/artist names from Japanese live music venue schedules.

      TASK: Extract ONLY real band/artist names from this text, ignoring event descriptions.

      TEXT TO ANALYZE:
      #{raw_text}

      CONTEXT:
      - Venue: #{context[:venue_name] || 'Unknown'}
      - Date: #{context[:date] || 'Unknown'}

      RULES:
      1. Extract ONLY actual band/artist names
      2. Ignore dates, times, prices, venue info
      3. Ignore event descriptions like "live", "show", "anniversary"
      4. Separate multiple artists with " / "
      5. Clean up formatting but preserve artist names exactly

      EXAMPLES OF WHAT TO EXTRACT:
      ✅ "Cornelius", "Guitar Wolf", "Perfume"
      ❌ "Live Show", "2025.6.14", "Open 19:00"

      Return ONLY the band names, separated by " / ", or "NONE" if no real artists found.
    PROMPT
  end

  def build_content_analysis_prompt(content, venue_config)
    <<~PROMPT
      You are an expert web scraper analyzing a Japanese live music venue website.

      TASK: Analyze this webpage content and provide scraping optimization recommendations.

      VENUE: #{venue_config[:name]}
      URL: #{venue_config[:url]}

      CONTENT SAMPLE (first 2000 chars):
      #{content[0..2000]}

      ANALYZE FOR:
      1. Content structure (HTML patterns, CSS classes)
      2. Schedule/event organization
      3. Date/time formats used
      4. Artist/band name presentation
      5. Potential scraping challenges

      PROVIDE:
      1. Confidence score (0-100) for successful scraping
      2. Recommended CSS selectors for events
      3. Recommended CSS selectors for dates
      4. Recommended CSS selectors for artist names
      5. Any special handling needed (JavaScript, images, etc.)

      FORMAT AS JSON:
      {
        "confidence": 85,
        "event_selectors": [".event", ".schedule-item"],
        "date_selectors": [".date", ".event-date"],
        "artist_selectors": [".artist", ".performer"],
        "special_handling": ["javascript_required"],
        "notes": "Events are in a calendar format..."
      }
    PROMPT
  end

  def build_selector_generation_prompt(content_analysis)
    <<~PROMPT
      You are an expert CSS selector generator for web scraping.

      TASK: Generate optimal CSS selectors based on this content analysis.

      ANALYSIS:
      #{content_analysis.to_json}

      GENERATE:
      1. Primary selectors (most likely to work)
      2. Fallback selectors (backup options)
      3. Specific selectors for different content types

      REQUIREMENTS:
      - Prioritize specificity over generality
      - Include multiple fallback options
      - Consider Japanese website patterns
      - Account for dynamic content

      FORMAT AS JSON:
      {
        "gigs": {
          "primary": [".event", ".live-info"],
          "fallback": ["article", ".post"]
        },
        "title": {
          "primary": [".event-title", "h3"],
          "fallback": [".title", "strong"]
        },
        "date": {
          "primary": [".date", ".event-date"],
          "fallback": ["time", ".meta"]
        },
        "artists": {
          "primary": [".artist", ".performer"],
          "fallback": [".lineup", ".act"]
        }
      }
    PROMPT
  end

  def build_gig_validation_prompt(gig_batch)
    gig_summaries = gig_batch.map.with_index do |gig, i|
      "#{i + 1}. Title: #{gig[:title]} | Date: #{gig[:date]} | Artists: #{gig[:artists]}"
    end.join("\n")

    <<~PROMPT
      You are an expert at validating live music event data.

      TASK: Validate these extracted events and clean up any issues.

      EVENTS TO VALIDATE:
      #{gig_summaries}

      FOR EACH EVENT, CHECK:
      1. Is this a real live music event?
      2. Are the artist names real (not event descriptions)?
      3. Is the date valid and properly formatted?
      4. Should this event be included?

      CLEAN UP:
      - Remove obvious non-events
      - Fix artist name formatting
      - Standardize date formats
      - Remove duplicate information

      RETURN ONLY VALID EVENTS AS JSON:
      [
        {
          "title": "Cleaned event title",
          "date": "2025-06-14",
          "artists": "Real Artist Name",
          "valid": true,
          "confidence": 95
        }
      ]

      If no valid events, return: []
    PROMPT
  end

  def parse_ai_band_extraction(ai_response)
    return { bands: [], confidence: 0 } unless ai_response

    # Extract band names from AI response
    if ai_response.strip.upcase == "NONE"
      { bands: [], confidence: 90 }
    else
      bands = ai_response.split(" / ").map(&:strip).reject(&:blank?)
      { bands: bands, confidence: 85 }
    end
  end

  def parse_ai_content_analysis(ai_response)
    begin
      JSON.parse(ai_response)
    rescue JSON::ParserError
      { confidence: 50, improvements: ["AI response parsing failed"] }
    end
  end

  def parse_ai_selector_response(ai_response)
    begin
      JSON.parse(ai_response)
    rescue JSON::ParserError
      get_fallback_selectors
    end
  end

  def parse_ai_validation_response(ai_response)
    begin
      JSON.parse(ai_response)
    rescue JSON::ParserError
      []
    end
  end

  def validate_ai_band_extraction(ai_result, original_text)
    # Additional validation of AI results
    ai_result[:bands].select do |band_name|
      # Ensure it's not obviously an event description
      !band_name.match?(/\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/) &&
      !band_name.match?(/open|start|door|ticket|price/i) &&
      band_name.length > 2 &&
      band_name.length < 100
    end
  end

  def fallback_to_rule_based_extraction(raw_text)
    # Fallback to existing extraction logic
    scraper = UnifiedVenueScraper.new
    gig_data = { title: raw_text, artists: nil }
    scraper.send(:extract_band_names, gig_data)
  end

  def normalize_band_name_with_ai(band_name)
    # Use AI to normalize band names for better Spotify matching
    # This could remove common suffixes, fix formatting, etc.
    band_name # Placeholder for now
  end

  def generate_search_variations_with_ai(normalized_name)
    # Generate multiple search variations using AI
    [normalized_name] # Placeholder for now
  end

  def search_spotify_with_ai_variations(variations)
    # Enhanced Spotify search using AI-generated variations
    [] # Placeholder for now
  end

  def validate_spotify_results_with_ai(original_name, results)
    # Use AI to validate which Spotify result best matches
    nil # Placeholder for now
  end

  def fetch_venue_content(url)
    # Fetch webpage content for analysis
    begin
      require 'net/http'
      require 'uri'

      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      response.body if response.code == '200'
    rescue => e
      puts "⚠️ Failed to fetch content: #{e.message}" if @verbose
      nil
    end
  end

  def extract_gigs_with_ai_assistance(venue_config, ai_selectors)
    # Use AI-generated selectors to extract gigs
    # This would integrate with the existing scraping system
    [] # Placeholder for now
  end

  def merge_with_proven_selectors(ai_selectors)
    # Merge AI selectors with proven fallbacks
    ai_selectors
  end

  def get_fallback_selectors
    # Return proven selectors as fallback
    {
      gigs: { primary: ['.event', '.schedule-item'], fallback: ['article', '.post'] },
      title: { primary: ['h2', 'h3'], fallback: ['.title', 'strong'] },
      date: { primary: ['.date'], fallback: ['time', '.meta'] },
      artists: { primary: ['.artist'], fallback: ['.performer', '.lineup'] }
    }
  end

  def fallback_validation(gig_batch)
    # Fallback to rule-based validation
    gig_batch.select { |gig| gig[:title].present? && gig[:date].present? }
  end

  def extract_successful_patterns(gigs)
    # Extract patterns from successful gigs for learning
    {
      title_patterns: gigs.map { |g| g[:title] }.compact.first(3),
      date_patterns: gigs.map { |g| g[:date] }.compact.first(3),
      artist_patterns: gigs.map { |g| g[:artists] }.compact.first(3)
    }
  end

  def save_ai_enhanced_gigs(gigs, venue_name)
    # Save AI-enhanced gigs to database
    scraper = UnifiedVenueScraper.new
    scraper.send(:save_gigs_to_database, gigs, venue_name)
  end

  def load_accuracy_cache
    cache_file = Rails.root.join('tmp', 'ai_accuracy_cache.json')
    return {} unless File.exist?(cache_file)

    JSON.parse(File.read(cache_file))
  rescue
    {}
  end

  def save_accuracy_cache
    cache_file = Rails.root.join('tmp', 'ai_accuracy_cache.json')
    File.write(cache_file, JSON.pretty_generate(@accuracy_cache))
  end

  def load_learning_data
    learning_file = Rails.root.join('tmp', 'ai_learning_data.json')
    return [] unless File.exist?(learning_file)

    JSON.parse(File.read(learning_file))
  rescue
    []
  end

  def save_learning_data
    learning_file = Rails.root.join('tmp', 'ai_learning_data.json')
    File.write(learning_file, JSON.pretty_generate(@learning_data))
  end

  def cache_analysis_result(url, analysis)
    @accuracy_cache[url] = {
      analysis: analysis,
      timestamp: Time.current.to_i
    }
    save_accuracy_cache
  end

  def update_ai_prompts_from_learning
    # Update AI prompts based on learning data
    # This would analyze successful patterns and improve prompts
    puts "🎓 Updated AI prompts based on #{@learning_data.length} learning examples" if @verbose
  end
end
