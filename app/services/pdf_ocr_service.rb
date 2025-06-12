require 'pdf-reader'
require 'mini_magick'
require 'open-uri'
require 'fileutils'

class PdfOcrService
  class << self
    def extract_text_from_pdfs(pdf_data)
      return [] if pdf_data.blank?

      extracted_gigs = []

      pdf_data.each do |pdf_info|
        begin
          text = extract_text_from_pdf(pdf_info[:url], pdf_info[:alt] || '')
          next if text.blank?

          # Parse the extracted text for gig information
          gigs = parse_schedule_text(text, pdf_info)
          extracted_gigs.concat(gigs)
        rescue => e
          Rails.logger.warn "PDF OCR failed for #{pdf_info[:url]}: #{e.message}"
        end
      end

      extracted_gigs
    end

    private

    def extract_text_from_pdf(pdf_url, alt_text = '')
      # Create temporary directory for PDF processing
      temp_dir = Rails.root.join('tmp', 'pdf_ocr')
      FileUtils.mkdir_p(temp_dir)

      # Download the PDF temporarily
      pdf_path = download_pdf(pdf_url, temp_dir)
      return '' if pdf_path.nil?

      begin
        # Try text extraction first (faster for text-based PDFs)
        text = extract_text_from_pdf_directly(pdf_path)

        if text.present? && text.length > 50
          puts "    📄 Direct PDF text extraction: #{text.length} characters from #{File.basename(pdf_url)}"
          return text
        end

        # Fallback: Convert PDF to images and use OCR
        puts "    🖼️  PDF appears to be image-based, converting to images for OCR..."
        text = extract_text_from_pdf_via_ocr(pdf_path, pdf_url)

        puts "    📝 PDF OCR extracted #{text.length} characters from #{File.basename(pdf_url)}"
        text
      ensure
        # Clean up temporary files
        File.delete(pdf_path) if File.exist?(pdf_path)
        # Clean up any generated image files
        Dir.glob(File.join(temp_dir, "#{File.basename(pdf_path, '.*')}_*.png")).each do |img_file|
          File.delete(img_file)
        end
      end
    end

    def download_pdf(pdf_url, temp_dir)
      return nil if pdf_url.blank?

      # Generate unique filename
      timestamp = Time.current.to_i
      filename = "pdf_#{timestamp}.pdf"
      pdf_path = File.join(temp_dir, filename)

      # Download the PDF with timeout and error handling
      begin
        URI.open(pdf_url, 'rb', read_timeout: 30) do |pdf_file|
          File.open(pdf_path, 'wb') do |file|
            file.write(pdf_file.read)
          end
        end

        # Verify the file was downloaded and has content
        return File.exist?(pdf_path) && File.size(pdf_path) > 0 ? pdf_path : nil
      rescue => e
        Rails.logger.warn "Failed to download PDF #{pdf_url}: #{e.message}"
        File.delete(pdf_path) if File.exist?(pdf_path)
        nil
      end
    end

    def extract_text_from_pdf_directly(pdf_path)
      reader = PDF::Reader.new(pdf_path)
      text = ""

      reader.pages.each do |page|
        page_text = page.text.strip
        text += page_text + "\n" if page_text.present?
      end

      text.strip
    rescue => e
      Rails.logger.warn "Direct PDF text extraction failed: #{e.message}"
      ""
    end

    def extract_text_from_pdf_via_ocr(pdf_path, pdf_url)
      temp_dir = File.dirname(pdf_path)
      base_name = File.basename(pdf_path, '.pdf')

      # Convert PDF to images using MiniMagick
      images = convert_pdf_to_images(pdf_path, temp_dir, base_name)
      return "" if images.empty?

      # Create image data for OCR services
      images_data = images.map.with_index do |image_path, index|
        {
          url: image_path,
          alt: "PDF page #{index + 1}",
          venue_name: 'PDF Document',
          relevance_score: 10  # High relevance for PDF content
        }
      end

      # Use smart OCR fallback on the images
      all_text = ""

      # Try EasyOCR first (best for mixed language content)
      begin
        gigs = EasyOcrService.extract_text_from_images(images_data)
        if gigs.any?
          all_text = gigs.map { |g| g[:raw_text] || g[:title] }.join("\n")
        end
      rescue => e
        Rails.logger.warn "EasyOCR failed on PDF images: #{e.message}"
      end

      # Fallback to Tesseract if EasyOCR didn't work
      if all_text.blank?
        begin
          gigs = OcrService.extract_text_from_images(images_data)
          if gigs.any?
            all_text = gigs.map { |g| g[:raw_text] || g[:title] }.join("\n")
          end
        rescue => e
          Rails.logger.warn "Tesseract failed on PDF images: #{e.message}"
        end
      end

      all_text
    end

    def convert_pdf_to_images(pdf_path, temp_dir, base_name)
      images = []

      begin
        # Use MiniMagick to convert PDF pages to images
        image = MiniMagick::Image.open(pdf_path)

        # Convert each page to a separate PNG
        image.format "png"
        image.density "300"  # High DPI for better OCR

        # Handle multi-page PDFs
        if image.pages.count > 1
          image.pages.each_with_index do |page, index|
            output_path = File.join(temp_dir, "#{base_name}_page_#{index + 1}.png")
            page.write(output_path)
            images << output_path
          end
        else
          output_path = File.join(temp_dir, "#{base_name}_page_1.png")
          image.write(output_path)
          images << output_path
        end

        puts "    📄 Converted PDF to #{images.count} images for OCR"
        images
      rescue => e
        Rails.logger.warn "PDF to image conversion failed: #{e.message}"
        []
      end
    end

    def parse_schedule_text(text, pdf_info)
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
                venue_name: pdf_info[:venue_name] || 'PDF Venue',
                source: 'pdf_ocr',
                source_url: pdf_info[:url],
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

      puts "    🎯 PDF OCR found #{gigs.count} potential gigs after parsing"
      Rails.logger.info "PDF OCR extracted #{gigs.count} gigs from PDF text"
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
