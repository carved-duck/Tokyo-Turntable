require 'rtesseract'
require 'open-uri'
require 'fileutils'

class OcrService
  class << self
    def extract_text_from_images(images_data)
      return [] if images_data.blank?

      extracted_gigs = []

      images_data.each do |image_info|
        begin
          text = extract_text_from_image(image_info[:url], image_info[:alt] || '')
          next if text.blank?

          # Parse the extracted text for gig information
          gigs = parse_schedule_text(text, image_info)
          extracted_gigs.concat(gigs)
        rescue => e
          Rails.logger.warn "OCR failed for image #{image_info[:url]}: #{e.message}"
        end
      end

      extracted_gigs
    end

    private

    def extract_text_from_image(image_url, alt_text = '')
      # Create temporary directory for image processing
      temp_dir = Rails.root.join('tmp', 'ocr')
      FileUtils.mkdir_p(temp_dir)

      # Download and save the image temporarily
      image_path = download_image(image_url, temp_dir)
      return '' if image_path.nil?

      begin
        # Configure RTesseract for Japanese text recognition
        # Support both Japanese and English characters
        image = RTesseract.new(image_path, lang: 'jpn+eng')

                # Extract text with better configuration for schedules
        extracted_text = image.to_s.strip

        puts "    📝 OCR extracted #{extracted_text.length} characters from #{File.basename(image_url)}"
        puts "    🔤 Raw text: #{extracted_text[0..300]}..." if extracted_text.length > 0
        Rails.logger.info "OCR extracted text from #{image_url}: #{extracted_text[0..200]}..."
        extracted_text
      ensure
        # Clean up temporary file
        File.delete(image_path) if File.exist?(image_path)
      end
    end

        def download_image(image_url, temp_dir)
      return nil if image_url.blank?

      # Skip non-raster image formats that OCR can't process
      uri = URI.parse(image_url)
      extension = File.extname(uri.path).downcase
      unsupported_formats = ['.svg', '.pdf', '.eps', '.ai', '.psd', '.ico']

      if unsupported_formats.include?(extension)
        puts "    ⏭️  Skipping #{extension} file (not supported by OCR): #{File.basename(image_url)}"
        return nil
      end

      # Generate unique filename
      timestamp = Time.current.to_i
      extension = '.jpg' if extension.blank?
      filename = "ocr_image_#{timestamp}#{extension}"
      image_path = File.join(temp_dir, filename)

      # Download the image with timeout and error handling
      begin
        URI.open(image_url, 'rb', read_timeout: 10) do |image_file|
          File.open(image_path, 'wb') do |file|
            file.write(image_file.read)
          end
        end

        # Verify the file was downloaded and has content
        return File.exist?(image_path) && File.size(image_path) > 0 ? image_path : nil
      rescue => e
        Rails.logger.warn "Failed to download image #{image_url}: #{e.message}"
        File.delete(image_path) if File.exist?(image_path)
        nil
      end
    end

    def parse_schedule_text(text, image_info)
      return [] if text.blank?

      gigs = []

      # Enhanced date patterns for Japanese venues
      date_patterns = [
        # Standard date formats
        /(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})/,
        /(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})/,
        /(\d{1,2})[\/\-\.](\d{1,2})/,

        # Japanese date formats
        /(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日/,
        /(\d{1,2})月\s*(\d{1,2})日/,

        # Compact formats
        /(\d{4})(\d{2})(\d{2})/,
        /(\d{2})(\d{2})/,

        # Day of week patterns (Japanese)
        /(月|火|水|木|金|土|日)曜日?/,
        /(Mon|Tue|Wed|Thu|Fri|Sat|Sun)/i
      ]

      # Split text into lines for processing
      lines = text.split(/\n|\r\n?/).map(&:strip).reject(&:blank?)

      current_year = Date.current.year
      current_month = Date.current.month

      lines.each_with_index do |line, index|
        # Try to find dates in each line
        date_patterns.each do |pattern|
          matches = line.scan(pattern)

          matches.each do |match|
            begin
              parsed_date = parse_date_from_match(match, current_year, current_month)
              next unless parsed_date

              # Extract title from the same line or nearby lines
              title = extract_title_from_line(line, lines, index)
              next if title.blank? || title.length < 2

              # Create gig entry
              gigs << {
                title: title,
                date: parsed_date,
                venue_name: image_info[:venue_name] || '',
                source: 'ocr_image',
                source_url: image_info[:url],
                artists: title,
                raw_text: line
              }
            rescue => e
              Rails.logger.debug "Date parsing failed for match #{match}: #{e.message}"
            end
          end
        end
      end

      # Remove duplicates and filter reasonable dates
      gigs = gigs.uniq { |g| [g[:date], g[:title]] }
      gigs = gigs.select { |g| valid_gig_date?(g[:date]) }

      puts "    🎯 OCR found #{gigs.count} potential gigs after parsing"
      Rails.logger.info "OCR extracted #{gigs.count} gigs from image text"
      gigs
    end

    def parse_date_from_match(match, current_year, current_month)
      case match.length
      when 3 # Year, month, day
        year, month, day = match.map(&:to_i)
        Date.new(year, month, day)
      when 2 # Month, day (assume current year)
        month, day = match.map(&:to_i)
        Date.new(current_year, month, day)
      when 1 # Day of week or single component
        # For day of week, we'd need additional context
        nil
      else
        nil
      end
    rescue Date::Error
      nil
    end

    def extract_title_from_line(line, all_lines, line_index)
      # Remove date patterns to get the title
      title = line.dup

      # Remove common date patterns
      title.gsub!(/\d{4}[\/\-\.]?\d{1,2}[\/\-\.]?\d{1,2}/, '')
      title.gsub!(/\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]?\d{4}?/, '')
      title.gsub!(/\d{4}年\s*\d{1,2}月\s*\d{1,2}日/, '')
      title.gsub!(/\d{1,2}月\s*\d{1,2}日/, '')
      title.gsub!(/(月|火|水|木|金|土|日)曜日?/, '')
      title.gsub!(/(Mon|Tue|Wed|Thu|Fri|Sat|Sun)/i, '')

      # Remove time patterns
      title.gsub!(/\d{1,2}:\d{2}/, '')
      title.gsub!(/\d{1,2}時\d{2}分?/, '')

      # Clean up the title
      title = title.strip.gsub(/\s+/, ' ')

      # If title is too short, try to get more context from nearby lines
      if title.length < 3 && line_index > 0
        prev_line = all_lines[line_index - 1]
        if prev_line && prev_line.length > 3
          title = "#{prev_line.strip} #{title}".strip
        end
      end

      # Remove common venue-related words that aren't event titles
      cleanup_patterns = [
        /^(schedule|スケジュール|予定|日程)/i,
        /^(event|イベント)/i,
        /^(live|ライブ)/i,
        /^(concert|コンサート)/i
      ]

      cleanup_patterns.each do |pattern|
        title.gsub!(pattern, '')
      end

      title.strip
    end

    def valid_gig_date?(date)
      return false unless date.is_a?(Date)

      # Accept dates within reasonable range (6 months in future, not in past)
      today = Date.current
      date >= today && date <= (today + 6.months)
    end
  end
end
