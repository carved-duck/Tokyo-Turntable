class IntelligentBandExtractor
  def initialize(options = {})
    @verbose = options[:verbose] || false
    @confidence_threshold = options[:confidence_threshold] || 0.7
  end

  # 🎵 MAIN INTELLIGENT EXTRACTION METHOD
  def extract_bands_from_gig_data(gig_data)
    puts "🎵 Intelligent band extraction from: #{gig_data[:title]}" if @verbose

    # Stage 1: Extract all potential band names
    candidates = extract_all_candidates(gig_data)

    # Stage 2: Score and validate each candidate
    scored_candidates = score_candidates(candidates, gig_data)

    # Stage 3: Select best candidates
    selected_bands = select_best_bands(scored_candidates)

    # Stage 4: Clean and finalize
    final_bands = finalize_band_names(selected_bands)

    puts "🎯 Extracted #{final_bands.length} bands: #{final_bands.join(', ')}" if @verbose

    final_bands.any? ? final_bands : ["Live Performance"]
  end

  private

  # 🔍 STAGE 1: EXTRACT ALL POTENTIAL CANDIDATES
  def extract_all_candidates(gig_data)
    candidates = []

    # From artists field (highest priority)
    if gig_data[:artists].present?
      candidates.concat(extract_from_artists_field(gig_data[:artists]))
    end

    # From title field (with intelligent parsing)
    if gig_data[:title].present?
      candidates.concat(extract_from_title_field(gig_data[:title]))
    end

    # From raw text (fallback)
    if gig_data[:raw_text].present?
      candidates.concat(extract_from_raw_text(gig_data[:raw_text]))
    end

    candidates.uniq.reject(&:blank?)
  end

  def extract_from_artists_field(artists_text)
    puts "  🎤 Extracting from artists: #{artists_text[0..50]}..." if @verbose

    # Clean the text first
    cleaned = preprocess_text(artists_text)

    # Split on separators
    separators = [' / ', ' × ', ' & ', ' and ', '、', '・', ' + ', ' with ', ' feat. ', ' featuring ', ' vs. ', ' VS ', ' x ']
    candidates = [cleaned]

    separators.each do |sep|
      candidates = candidates.flat_map { |text| text.split(sep) }
    end

    candidates.map(&:strip).reject(&:blank?)
  end

  def extract_from_title_field(title_text)
    puts "  📝 Extracting from title: #{title_text[0..50]}..." if @verbose

    candidates = []

    # Pattern 1: "Artist Name Live" or "Artist Name Show"
    if match = title_text.match(/^(.+?)\s+(live|show|concert|performance)$/i)
      candidates << match[1].strip
    end

    # Pattern 2: "Live: Artist Name" or "Show: Artist Name"
    if match = title_text.match(/^(live|show|concert)[:：]\s*(.+)$/i)
      candidates << match[2].strip
    end

    # Pattern 3: "Artist Name ● Event Info" (extract artist part)
    if match = title_text.match(/^([^●○■□▲△▼▽◆◇★☆]+?)\s*[●○■□▲△▼▽◆◇★☆](.*)$/i)
      artist_part = match[1].strip
      event_part = match[2].strip

      # Only use artist part if it looks like an artist
      candidates << artist_part if looks_like_artist?(artist_part)

      # Also try to extract from event part
      candidates.concat(extract_from_event_description(event_part))
    end

    # Pattern 4: Japanese event format "日付 アーティスト名 イベント情報"
    if match = title_text.match(/^(\d{1,2}[\/\-\.]\d{1,2}|\d{1,2}\s*\([月火水木金土日]\)|\d{1,2}\s+(sat|sun|mon|tue|wed|thu|fri)|\d{4}\.\d{1,2})\s+(.+)$/i)
      remaining_text = match[match.length - 1]&.strip # Get the last capture group
      candidates.concat(extract_from_event_description(remaining_text)) if remaining_text
    end

    # Pattern 5: "Date Venue Artist" format like "14 Sat WWW 幽体コミュニケーションズ"
    if match = title_text.match(/^(\d{1,2}\s+(sat|sun|mon|tue|wed|thu|fri))\s+(www|zepp|club|hall|bar)\s+(.+)$/i)
      artist_part = match[4].strip
      candidates << artist_part if looks_like_artist?(artist_part)
    end

    # Pattern 6: Extract artist from complex Japanese titles
    if title_text.match?(/トリオ|カルテット|バンド|オーケストラ/)
      # Look for artist name before event description
      if match = title_text.match(/^([^『「]*(?:トリオ|カルテット|バンド|オーケストラ)[^『「]*?)[\s『「]/i)
        artist_part = match[1].strip
        candidates << artist_part if looks_like_artist?(artist_part)
      end
    end

          # Pattern 7: Complex event titles with multiple artists
      candidates.concat(extract_multiple_artists_from_title(title_text))

    candidates.reject(&:blank?)
  end

  def extract_from_raw_text(raw_text)
    puts "  📄 Extracting from raw text: #{raw_text[0..50]}..." if @verbose

    # Look for artist names in structured text
    lines = raw_text.split(/\n|\r/).map(&:strip).reject(&:blank?)

    candidates = []

    lines.each do |line|
      # Skip obvious non-artist lines
      next if line.match?(/^(open|start|door|ticket|price|admission|¥|\$)/i)
      next if line.match?(/^\d{1,2}:\d{2}/) # Time lines
      next if line.match?(/^\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/) # Date lines

      # Extract potential artists from each line
      line_candidates = extract_artists_from_line(line)
      candidates.concat(line_candidates)
    end

    candidates.reject(&:blank?)
  end

  def extract_multiple_artists_from_title(title)
    # Handle complex titles with multiple artists
    candidates = []

    # Look for "Artist1 / Artist2 / Artist3" patterns
    if title.include?(' / ')
      parts = title.split(' / ')
      parts.each { |part| candidates << part.strip if looks_like_artist?(part.strip) }
    end

    # Look for "Artist1 & Artist2" patterns
    if title.include?(' & ') && !title.match?(/\d+\s*&\s*\d+/) # Not "18 & over"
      parts = title.split(' & ')
      parts.each { |part| candidates << part.strip if looks_like_artist?(part.strip) }
    end

    # Look for Japanese separator patterns
    if title.include?('、')
      parts = title.split('、')
      parts.each { |part| candidates << part.strip if looks_like_artist?(part.strip) }
    end

    candidates
  end

  def extract_from_event_description(event_text)
    candidates = []

    # Remove common event prefixes
    cleaned = event_text.gsub(/^(presents?|invites?|featuring|guest|special|with)[:：\s]+/i, '')

    # Look for artist names in parentheses
    parentheses_matches = cleaned.scan(/\(([^)]+)\)/)
    parentheses_matches.each do |match|
      content = match[0].strip
      candidates << content if looks_like_artist?(content)
    end

    # Look for quoted artist names
    quoted_matches = cleaned.scan(/"([^"]+)"/)
    quoted_matches.each do |match|
      content = match[0].strip
      candidates << content if looks_like_artist?(content)
    end

    # Extract from remaining text after removing obvious event info
    remaining = cleaned.gsub(/\([^)]*\)/, '').gsub(/"[^"]*"/, '').strip
    if remaining.present? && looks_like_artist?(remaining)
      candidates << remaining
    end

    candidates
  end

  def extract_artists_from_line(line)
    candidates = []

    # Remove time stamps
    cleaned = line.gsub(/\d{1,2}:\d{2}/, '').strip

    # Remove date stamps
    cleaned = cleaned.gsub(/\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}/, '').strip
    cleaned = cleaned.gsub(/\d{1,2}[\/\-\.]\d{1,2}/, '').strip

    # Remove venue info
    cleaned = cleaned.gsub(/\b(at|@|venue|club|hall|bar|studio)\s+[^,\n]+/i, '').strip

    # Split on common separators
    separators = [',', '/', '&', '+', '×', '・']
    parts = [cleaned]

    separators.each do |sep|
      parts = parts.flat_map { |part| part.split(sep) }
    end

    parts.each do |part|
      cleaned_part = part.strip
      candidates << cleaned_part if looks_like_artist?(cleaned_part)
    end

    candidates
  end

  # 🎯 STAGE 2: SCORE AND VALIDATE CANDIDATES
  def score_candidates(candidates, gig_data)
    scored = candidates.map do |candidate|
      score = calculate_artist_confidence(candidate, gig_data)
      {
        name: candidate,
        score: score,
        reasons: get_scoring_reasons(candidate, gig_data)
      }
    end

    scored.sort_by { |item| -item[:score] }
  end

  def calculate_artist_confidence(candidate, gig_data)
    score = 0.5 # Base score

    # Positive indicators
    score += 0.3 if looks_like_artist?(candidate)
    score += 0.2 if has_artist_keywords?(candidate)
    score += 0.2 if proper_length?(candidate)
    score += 0.1 if has_mixed_case?(candidate)
    score += 0.1 if has_japanese_characters?(candidate)
    score += 0.15 if appears_in_artists_field?(candidate, gig_data)
    score += 0.1 if has_band_suffixes?(candidate)

    # Negative indicators
    score -= 0.4 if is_date_pattern?(candidate)
    score -= 0.3 if is_time_pattern?(candidate)
    score -= 0.3 if is_venue_info?(candidate)
    score -= 0.2 if is_event_description?(candidate)
    score -= 0.2 if is_pricing_info?(candidate)
    score -= 0.1 if too_short?(candidate)
    score -= 0.2 if too_long?(candidate)
    score -= 0.3 if mostly_symbols?(candidate)
    score -= 0.2 if generic_event_term?(candidate)

    # Ensure score is between 0 and 1
    [[score, 0].max, 1].min
  end

  def get_scoring_reasons(candidate, gig_data)
    reasons = []

    reasons << "looks_like_artist" if looks_like_artist?(candidate)
    reasons << "has_artist_keywords" if has_artist_keywords?(candidate)
    reasons << "proper_length" if proper_length?(candidate)
    reasons << "in_artists_field" if appears_in_artists_field?(candidate, gig_data)
    reasons << "date_pattern" if is_date_pattern?(candidate)
    reasons << "venue_info" if is_venue_info?(candidate)
    reasons << "event_description" if is_event_description?(candidate)
    reasons << "too_short" if too_short?(candidate)
    reasons << "too_long" if too_long?(candidate)

    reasons
  end

  # 🏆 STAGE 3: SELECT BEST CANDIDATES
  def select_best_bands(scored_candidates)
    # Filter by confidence threshold
    high_confidence = scored_candidates.select { |item| item[:score] >= @confidence_threshold }

    # If no high confidence candidates, take the best ones
    if high_confidence.empty?
      high_confidence = scored_candidates.first(2) # Take top 2
    end

    # Limit to maximum 3 bands
    selected = high_confidence.first(3)

    puts "  🎯 Selected #{selected.length} candidates above threshold #{@confidence_threshold}" if @verbose
    selected.each { |item| puts "    - #{item[:name]} (#{item[:score].round(2)}): #{item[:reasons].join(', ')}" } if @verbose

    selected.map { |item| item[:name] }
  end

  # 🧹 STAGE 4: FINALIZE BAND NAMES
  def finalize_band_names(selected_bands)
    selected_bands.map { |name| clean_final_band_name(name) }
                  .reject(&:blank?)
                  .uniq
  end

  def clean_final_band_name(name)
    # Remove common prefixes/suffixes
    cleaned = name.gsub(/^(DJ|dj)\s+/i, '') unless name.match?(/^DJ\s+[A-Z]/i)
    cleaned = cleaned.gsub(/\s+(live|show|event|performance|set)$/i, '')
    cleaned = cleaned.gsub(/^(the\s+)?live\s+/i, '')

    # Remove event info in parentheses
    cleaned = cleaned.gsub(/\s*\([^)]*(?:live|show|event|tour|release)\s*[^)]*\)\s*/i, '')

    # Remove venue/location info
    cleaned = cleaned.gsub(/\s*\([^)]*(?:from|@|at|venue|club|bar|hall|tokyo|japan)\s*[^)]*\)\s*/i, '')

    # Remove symbols
    cleaned = cleaned.gsub(/\s*[●○■□▲△▼▽◆◇★☆]\s*/, ' ')

    # Clean whitespace
    cleaned = cleaned.gsub(/\s+/, ' ').strip

    cleaned
  end

  # 🔍 HELPER METHODS FOR SCORING
  def preprocess_text(text)
    # Remove common event prefixes
    text = text.gsub(/^(出演|出演者|アーティスト|artist|performers?|featuring|guest|special|live|show)[:：\s]+/i, '')

    # Remove DJ prefixes when they're clearly event descriptions
    text = text.gsub(/^●?DJ[:：]\s*/i, '') if text.match?(/●?DJ[:：]\s*[A-Z\s]+\(/i)

    # Remove venue/event info in parentheses
    text = text.gsub(/\s*\([^)]*(?:from|@|at|venue|club|bar|hall)\s*[^)]*\)\s*$/i, '')

    # Remove time/date info
    text = text.gsub(/\s*\d{1,2}:\d{2}\s*/, ' ')
    text = text.gsub(/\s*\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}\s*/, ' ')

    text.strip
  end

  def looks_like_artist?(text)
    return false unless text.present?
    return false if text.length < 2 || text.length > 80

    # Must contain some letters
    return false unless text.match?(/[a-zA-Zひらがなカタカナ漢字]/)

    # Should not be mostly numbers or symbols
    letter_count = text.scan(/[a-zA-Zひらがなカタカナ漢字]/).length
    return false if letter_count < text.length * 0.3

    # Should not contain obvious event markers
    return false if is_date_pattern?(text)
    return false if is_time_pattern?(text)
    return false if is_venue_info?(text)
    return false if is_pricing_info?(text)
    return false if generic_event_term?(text)

    true
  end

  def has_artist_keywords?(text)
    artist_keywords = [
      'band', 'trio', 'quartet', 'quintet', 'orchestra', 'ensemble',
      'バンド', 'トリオ', 'カルテット', 'オーケストラ', 'アンサンブル'
    ]

    artist_keywords.any? { |keyword| text.downcase.include?(keyword.downcase) }
  end

  def proper_length?(text)
    text.length >= 2 && text.length <= 50
  end

  def has_mixed_case?(text)
    text.match?(/[a-z]/) && text.match?(/[A-Z]/)
  end

  def has_japanese_characters?(text)
    text.match?(/[ひらがなカタカナ漢字]/)
  end

  def appears_in_artists_field?(candidate, gig_data)
    return false unless gig_data[:artists].present?
    gig_data[:artists].downcase.include?(candidate.downcase)
  end

  def has_band_suffixes?(text)
    suffixes = ['band', 'trio', 'quartet', 'orchestra', 'collective', 'project']
    suffixes.any? { |suffix| text.downcase.end_with?(suffix) }
  end

  def is_date_pattern?(text)
    text.match?(/^\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}$/) ||
    text.match?(/^\d{1,2}[\/\-\.]\d{1,2}$/) ||
    text.match?(/^\d{1,2}\s*\([月火水木金土日]\)$/) ||
    text.match?(/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+\d{1,2}$/i) ||
    text.match?(/^\d{1,2}\s*(sat|sun|mon|tue|wed|thu|fri)$/i) ||
    text.match?(/^\d{4}\.\d{1,2}$/) ||  # "2025.6" pattern
    text.match?(/^\d{1,2}\s+(sat|sun|mon|tue|wed|thu|fri)$/i) || # "14 Sat" pattern
    text.match?(/^(june|july|august|september|october|november|december)\s+\d{1,2}$/i) # "June 14" pattern
  end

  def is_time_pattern?(text)
    text.match?(/^\d{1,2}:\d{2}$/) ||
    text.match?(/^(open|start|door)\s*\d{1,2}:\d{2}$/i)
  end

  def is_venue_info?(text)
    venue_keywords = [
      'zepp', 'www', 'club', 'hall', 'bar', 'studio', 'venue', 'stage',
      'クラブ', 'ホール', 'バー', 'スタジオ', 'ステージ'
    ]

    venue_keywords.any? { |keyword| text.downcase.include?(keyword) }
  end

    def is_event_description?(text)
    event_patterns = [
      /anniversary|birthday|release|tour|festival|party|night|session/i,
      /live\s+(show|event|performance)|show\s+(live|event)/i,
      /\d+(st|nd|rd|th)\s+(anniversary|birthday)/i,
      /記念|誕生日|リリース|ツアー|フェス|パーティー/,
      /記念公演|リリース記念|special\s+performance/i
    ]

    event_patterns.any? { |pattern| text.match?(pattern) }
  end

  def is_pricing_info?(text)
    text.match?(/ticket|price|admission|advance|door|¥\d+|\$\d+|円/i)
  end

  def too_short?(text)
    text.length < 2
  end

  def too_long?(text)
    text.length > 80
  end

  def mostly_symbols?(text)
    symbol_count = text.scan(/[^a-zA-Zひらがなカタカナ漢字0-9\s]/).length
    symbol_count > text.length * 0.5
  end

  def generic_event_term?(text)
    generic_terms = [
      'live', 'show', 'event', 'performance', 'concert', 'festival', 'party', 'session', 'night',
      'ライブ', 'ショー', 'イベント', 'パフォーマンス', 'コンサート', 'フェス', 'パーティー'
    ]

    generic_terms.any? { |term| text.downcase.strip == term.downcase }
  end
end
