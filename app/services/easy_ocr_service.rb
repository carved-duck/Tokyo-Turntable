require 'open3'
require 'json'
require 'tempfile'

class EasyOcrService
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
          Rails.logger.warn "EasyOCR failed for image #{image_info[:url]}: #{e.message}"
        end
      end

      extracted_gigs
    end

    private

    def extract_text_from_image(image_url, alt_text)
      return '' if image_url.blank?

      temp_dir = Dir.mktmpdir('easy_ocr')
      image_path = download_image(image_url, temp_dir)
      return '' unless image_path

      begin
        # Create Python script to run EasyOCR
        python_script = create_easy_ocr_script(image_path)

        # Run EasyOCR via Python
        stdout, stderr, status = Open3.capture3("python3", python_script)

        if status.success?
          result = JSON.parse(stdout)
          extracted_text = result['text'] || ''
          puts "    📝 EasyOCR extracted #{extracted_text.length} characters from #{File.basename(image_url)}"
          puts "    🔤 Raw text: #{extracted_text[0..300]}..." if extracted_text.length > 0
          extracted_text
        else
          puts "    ❌ EasyOCR error: #{stderr}"
          ''
        end
      rescue JSON::ParserError => e
        puts "    ❌ EasyOCR JSON parse error: #{e.message}"
        puts "    📋 Raw output: #{stdout}"
        ''
      ensure
        FileUtils.rm_rf(temp_dir)
        File.delete(python_script) if python_script && File.exist?(python_script)
      end
    end

    def create_easy_ocr_script(image_path)
      script_content = <<~PYTHON
        import sys
        import json
        try:
            import easyocr
            import cv2
            import numpy as np

            # Initialize EasyOCR
            reader = easyocr.Reader(['en', 'ja'], gpu=False)

            # Read image
            img_path = sys.argv[1] if len(sys.argv) > 1 else '#{image_path}'

            # Perform OCR
            result = reader.readtext(img_path, detail=0)  # detail=0 returns only text

            # Join all text
            extracted_text = ' '.join(result) if result else ''

            # Output as JSON
            output = {
                'text': extracted_text,
                'success': True
            }
            print(json.dumps(output))

        except ImportError as e:
            output = {
                'text': '',
                'success': False,
                'error': f'EasyOCR not installed: {str(e)}'
            }
            print(json.dumps(output))
        except Exception as e:
            output = {
                'text': '',
                'success': False,
                'error': str(e)
            }
            print(json.dumps(output))
      PYTHON

      # Write to temporary Python file
      temp_script = Tempfile.new(['easy_ocr', '.py'])
      temp_script.write(script_content)
      temp_script.close
      temp_script.path
    end

        def download_image(image_url, temp_dir)
      return nil if image_url.blank?

      # Handle local files (for testing)
      if File.exist?(image_url)
        puts "    📁 Using local file: #{File.basename(image_url)}"
        return image_url  # Return the local path directly
      end

      # Skip unsupported formats
      uri = URI.parse(image_url)
      extension = File.extname(uri.path).downcase
      unsupported_formats = ['.svg', '.pdf', '.eps', '.ai', '.psd', '.ico']

      if unsupported_formats.include?(extension)
        puts "    ⏭️  Skipping #{extension} file (not supported by OCR): #{File.basename(image_url)}"
        return nil
      end

      timestamp = Time.current.to_i
      extension = '.jpg' if extension.blank?
      filename = "easy_ocr_image_#{timestamp}#{extension}"
      image_path = File.join(temp_dir, filename)

      begin
        URI.open(image_url) do |image_file|
          File.open(image_path, 'wb') do |file|
            file.write(image_file.read)
          end
        end

        image_path
      rescue => e
        puts "    ❌ Failed to download image #{image_url}: #{e.message}"
        nil
      end
    end

    def parse_schedule_text(text, image_info)
      return [] if text.blank?

      gigs = []
      lines = text.split(/\n|\r\n|\s+/).map(&:strip).reject(&:blank?)

      # Enhanced date patterns for Japanese venues
      date_patterns = [
        # Japanese dates
        /(\d{1,2})月(\d{1,2})日/,
        /(\d{4})[年\/\-](\d{1,2})[月\/\-](\d{1,2})[日]?/,

        # Western dates
        /(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})/,
        /(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/,
        /(\d{1,2})\.(\d{1,2})\.(\d{4})/,

        # Compact formats
        /(\d{8})/,  # YYYYMMDD
        /(\d{4})(\d{2})(\d{2})/,

        # Month day formats
        /(\d{1,2})\.(\d{1,2})/,
        /(\d{1,2})\/(\d{1,2})/,

        # Simple day.month format common in flyers
        /(\d{1,2})\.(\d{1,2})/
      ]

      current_date = nil
      current_title = nil

      # Try to find date and title in the text
      full_text = lines.join(' ')

      # Look for dates
      date_patterns.each do |pattern|
        if match = full_text.match(pattern)
          if pattern.source.include?('月') # Japanese format
            month = match[1].to_i
            day = match[2].to_i
            year = Time.current.year
            current_date = Date.new(year, month, day) rescue nil
          elsif match.captures.length >= 3
            if match[1].length == 4 # Year first
              year, month, day = match[1].to_i, match[2].to_i, match[3].to_i
            else # Day first
              day, month, year = match[1].to_i, match[2].to_i, match[3].to_i
            end
            current_date = Date.new(year, month, day) rescue nil
          elsif match.captures.length == 2
            month, day = match[1].to_i, match[2].to_i
            year = Time.current.year
            current_date = Date.new(year, month, day) rescue nil
          end
          break if current_date
        end
      end

      # Look for venue/event title
      lines.each do |line|
        if line.length > 3 && !line.match(/^\d+$/) && !line.match(/^[\/\-\.\s]+$/)
          # Skip obvious non-title lines
          skip_patterns = [
            /^(https?:\/\/|www\.)/i,
            /^[©®™]/,
            /^(tel|fax|phone|email)[:：]/i,
            /^[\d\s\-\+\(\)]+$/, # Just numbers/phone
            /^[\.]{3,}/, # Dots
            /^[\-]{3,}/, # Dashes
            /^(pm|am|開演|開場|料金|price|yen|円)$/i
          ]

          should_skip = skip_patterns.any? { |pattern| line.match?(pattern) }

          unless should_skip
            current_title = line if current_title.blank? || line.length > current_title.length
          end
        end
      end

      # Create gig if we found both date and title
      if current_date && current_title.present?
        gigs << {
          date: current_date,
          title: current_title,
          venue_name: image_info[:venue_name],
          source: 'easy_ocr',
          raw_text: text[0..500] # First 500 chars for debugging
        }
      end

      puts "    🎯 EasyOCR found #{gigs.count} potential gigs after parsing"
      gigs
    end
  end
end
