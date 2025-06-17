namespace :venues do
  desc "Test all OCR engines (Tesseract, PaddleOCR, EasyOCR) on MITSUKI and sample image"
  task test_multi_ocr: :environment do
    puts "🧪 COMPREHENSIVE OCR ENGINE COMPARISON"
    puts "="*60

    # Test 1: Sample Image OCR Comparison
    puts "\n📸 TEST 1: SAMPLE IMAGE COMPARISON"
    puts "-"*40

    sample_image_path = Rails.root.join('tmp', 'sample_schedule.jpeg').to_s

    if File.exist?(sample_image_path)
      puts "✅ Found sample image: #{sample_image_path}"

             # Prepare test image data (use direct path for local files)
       sample_image_data = [{
         url: sample_image_path,  # Direct path, not file:// URL
         alt: "Sample schedule flyer",
         venue_name: "Test Venue",
         relevance_score: 10
       }]

      # Test each OCR engine
      ocr_engines = [
        { name: 'Tesseract (RTesseract)', service: OcrService },
        { name: 'PaddleOCR', service: PaddleOcrService },
        { name: 'EasyOCR', service: EasyOcrService }
      ]

      results = {}

      ocr_engines.each do |engine|
        puts "\n🔍 Testing #{engine[:name]}..."
        puts "-"*30

        begin
          start_time = Time.current
          gigs = engine[:service].extract_text_from_images(sample_image_data)
          end_time = Time.current

          results[engine[:name]] = {
            success: true,
            gigs_count: gigs.count,
            processing_time: end_time - start_time,
            gigs: gigs
          }

          puts "✅ #{engine[:name]} completed in #{(end_time - start_time).round(2)}s"
          puts "📊 Found #{gigs.count} gigs"

          if gigs.any?
            gigs.each_with_index do |gig, i|
              puts "   Gig #{i+1}: #{gig[:date]} - #{gig[:title]}"
            end
          end

        rescue => e
          puts "❌ #{engine[:name]} failed: #{e.message}"
          results[engine[:name]] = {
            success: false,
            error: e.message,
            processing_time: 0,
            gigs_count: 0
          }
        end
      end

      # Summary of sample image results
      puts "\n📊 SAMPLE IMAGE RESULTS SUMMARY"
      puts "-"*40
      results.each do |engine_name, result|
        if result[:success]
          puts "#{engine_name}: ✅ #{result[:gigs_count]} gigs (#{result[:processing_time].round(2)}s)"
        else
          puts "#{engine_name}: ❌ Failed - #{result[:error]}"
        end
      end

    else
      puts "❌ Sample image not found at #{sample_image_path}"
      puts "💡 Please save a test image as tmp/sample_schedule.jpeg first"
    end

    # Test 2: MITSUKI Website OCR Comparison
    puts "\n\n🏢 TEST 2: MITSUKI WEBSITE COMPARISON"
    puts "-"*40

    mitsuki_config = {
      name: "翠月 (MITSUKI)",
      url: "https://mitsuki-tokyo.com/",
      type: "image_based_schedule"
    }

    puts "Testing venue: #{mitsuki_config[:name]}"
    puts "URL: #{mitsuki_config[:url]}"

    # Create scraper instance
    scraper = UnifiedVenueScraper.new(verbose: true)

    begin
      puts "\n🔍 Testing multi-OCR on MITSUKI website..."
      mitsuki_gigs = scraper.handle_image_based_schedule_venue(mitsuki_config)

      puts "\n📊 MITSUKI RESULTS:"
      puts "Found #{mitsuki_gigs.count} gigs total"

      if mitsuki_gigs.any?
        mitsuki_gigs.each_with_index do |gig, i|
          puts "   Gig #{i+1}: #{gig[:date]} - #{gig[:title]} (via #{gig[:source]})"
        end
      else
        puts "   No gigs found from any OCR engine"
      end

    rescue => e
      puts "❌ MITSUKI test failed: #{e.message}"
    end

    # Test 3: Quick OCR Engine Availability Check
    puts "\n\n🔧 TEST 3: OCR ENGINE AVAILABILITY"
    puts "-"*40

    # Test Tesseract
    puts "\n🔍 Tesseract availability:"
    begin
      RTesseract.new.to_s
      puts "✅ Tesseract (RTesseract): Available"
    rescue => e
      puts "❌ Tesseract (RTesseract): #{e.message}"
    end

    # Test PaddleOCR
    puts "\n🔍 PaddleOCR availability:"
    begin
      test_script = <<~PYTHON
        try:
            from paddleocr import PaddleOCR
            print("SUCCESS")
        except Exception as e:
            print(f"ERROR: {e}")
      PYTHON

      temp_script = Tempfile.new(['test_paddle', '.py'])
      temp_script.write(test_script)
      temp_script.close

      stdout, stderr, status = Open3.capture3("python3", temp_script.path)
      temp_script.unlink

      if stdout.strip == "SUCCESS"
        puts "✅ PaddleOCR: Available"
      else
        puts "❌ PaddleOCR: #{stdout.strip}"
      end
    rescue => e
      puts "❌ PaddleOCR: #{e.message}"
    end

    # Test EasyOCR
    puts "\n🔍 EasyOCR availability:"
    begin
      test_script = <<~PYTHON
        try:
            import easyocr
            print("SUCCESS")
        except Exception as e:
            print(f"ERROR: {e}")
      PYTHON

      temp_script = Tempfile.new(['test_easy', '.py'])
      temp_script.write(test_script)
      temp_script.close

      stdout, stderr, status = Open3.capture3("python3", temp_script.path)
      temp_script.unlink

      if stdout.strip == "SUCCESS"
        puts "✅ EasyOCR: Available"
      else
        puts "❌ EasyOCR: #{stdout.strip}"
      end
    rescue => e
      puts "❌ EasyOCR: #{e.message}"
    end

    puts "\n🎉 Multi-OCR testing complete!"
    puts "\n💡 Next steps:"
    puts "   - If any engines failed, install with: rake venues:install_python_ocr"
    puts "   - The best performing engine will be used automatically"
    puts "   - Production scraping: rake venues:test_ocr (for MITSUKI only)"
  end
end
