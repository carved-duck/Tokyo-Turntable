class EnhancedDateParser
  class << self
    def parse_date_with_enhanced_patterns(text, context = {})
      return nil unless text.present?

      text = text.strip
      current_year = Date.current.year
      current_month = Date.current.month

      # Try enhanced patterns first (higher success rate)
      enhanced_patterns.each do |pattern_info|
        if match = text.match(pattern_info[:regex])
          begin
            parsed_date = pattern_info[:parser].call(match, current_year, current_month)
            return parsed_date if parsed_date&.is_a?(Date)
          rescue => e
            Rails.logger.debug "Enhanced date parsing failed for pattern #{pattern_info[:name]}: #{e.message}"
          end
        end
      end

      # Fallback to standard patterns
      standard_patterns.each do |pattern_info|
        if match = text.match(pattern_info[:regex])
          begin
            parsed_date = pattern_info[:parser].call(match, current_year, current_month)
            return parsed_date if parsed_date&.is_a?(Date)
          rescue => e
            Rails.logger.debug "Standard date parsing failed for pattern #{pattern_info[:name]}: #{e.message}"
          end
        end
      end

      # Last resort: natural language parsing
      parse_natural_language_date(text)
    end

    private

    def enhanced_patterns
      [
        {
          name: 'Japanese compact with day',
          regex: /(\d{1,2})\.(\d{1,2})\s*\(([月火水木金土日])\)/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Japanese slash with day',
          regex: /(\d{1,2})\/(\d{1,2})\s*\(([月火水木金土日])\)/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Full Japanese with brackets',
          regex: /(\d{4})\.(\d{1,2})\.(\d{1,2})\s*\[([月火水木金土日])\]/,
          parser: ->(match, year, month) {
            year_val = match[1].to_i
            month_val = match[2].to_i
            day_val = match[3].to_i
            Date.new(year_val, month_val, day_val)
          }
        },
        {
          name: 'Japanese with time',
          regex: /(\d{1,2})月(\d{1,2})日\s*\(([月火水木金土日])\)\s*(\d{1,2}:\d{2})/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Venue compact format',
          regex: /(\d{4})(\d{2})(\d{2})\s*\[([a-z]{3})\.\]/,
          parser: ->(match, year, month) {
            year_val = match[1].to_i
            month_val = match[2].to_i
            day_val = match[3].to_i
            Date.new(year_val, month_val, day_val)
          }
        },
        {
          name: 'Dash format with day',
          regex: /(\d{1,2})-(\d{1,2})\s*\(([A-Z]{3})\)/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Date range start',
          regex: /(\d{1,2})\/(\d{1,2})\s*-\s*\d{1,2}\/\d{1,2}/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Relative today',
          regex: /今日\s*(\d{1,2})\/(\d{1,2})/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Relative tomorrow',
          regex: /明日\s*(\d{1,2})\/(\d{1,2})/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Relative next week',
          regex: /来週\s*(\d{1,2})\/(\d{1,2})/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        }
      ]
    end

    def standard_patterns
      [
        {
          name: 'ISO format',
          regex: /(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})/,
          parser: ->(match, year, month) {
            year_val = match[1].to_i
            month_val = match[2].to_i
            day_val = match[3].to_i
            Date.new(year_val, month_val, day_val)
          }
        },
        {
          name: 'Japanese full format',
          regex: /(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日/,
          parser: ->(match, year, month) {
            year_val = match[1].to_i
            month_val = match[2].to_i
            day_val = match[3].to_i
            Date.new(year_val, month_val, day_val)
          }
        },
        {
          name: 'Japanese month day',
          regex: /(\d{1,2})月\s*(\d{1,2})日/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            Date.new(year, month_val, day_val)
          }
        },
        {
          name: 'Compact YYYYMMDD',
          regex: /^(\d{4})(\d{2})(\d{2})$/,
          parser: ->(match, year, month) {
            year_val = match[1].to_i
            month_val = match[2].to_i
            day_val = match[3].to_i
            Date.new(year_val, month_val, day_val)
          }
        },
        {
          name: 'Month day only',
          regex: /^(\d{1,2})\/(\d{1,2})$/,
          parser: ->(match, year, month) {
            month_val = match[1].to_i
            day_val = match[2].to_i
            # Use current year, or next year if date has passed
            target_date = Date.new(year, month_val, day_val)
            target_date < Date.current ? Date.new(year + 1, month_val, day_val) : target_date
          }
        }
      ]
    end

    def parse_natural_language_date(text)
      # Clean up common Japanese date indicators
      cleaned_text = text.gsub(/[（）()【】\[\]]/, ' ')
                         .gsub(/[本日|今日|明日]/, '')
                         .gsub(/[開催|予定|から]/, '')
                         .strip

      return nil if cleaned_text.blank?

      begin
        Date.parse(cleaned_text)
      rescue Date::Error
        nil
      end
    end

    def valid_date_range?(date)
      return false unless date.is_a?(Date)

      today = Date.current
      # Accept dates within 6 months in the future, not in the past
      date >= today && date <= (today + 6.months)
    end
  end
end
