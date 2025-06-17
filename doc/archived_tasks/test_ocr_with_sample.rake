namespace :venues do
  desc "Test OCR with a sample image file"
  task test_ocr_sample: :environment do
    puts "🔍 TESTING OCR WITH SAMPLE IMAGE"
    puts "="*50

    # Accept image path as argument: rake venues:test_ocr_sample[path/to/image.jpg]
    image_path = ENV['IMAGE_PATH'] || Rails.root.join('tmp', 'sample_schedule.jpg').to_s

    if File.exist?(image_path)
      puts "✅ Found sample image: #{image_path}"

      begin
        # Test RTesseract directly on the sample image
        puts "\n🔧 Testing OCR with different configurations..."

        # Test 1: Japanese + English
        puts "\n📝 TEST 1: Japanese + English (jpn+eng)"
        image = RTesseract.new(image_path, lang: 'jpn+eng')
        text_jpn_eng = image.to_s.strip
        puts "📏 Extracted text length: #{text_jpn_eng.length} characters"
        puts "🔤 Text preview: #{text_jpn_eng[0..200]}..." if text_jpn_eng.length > 0

        # Test 2: English only
        puts "\n📝 TEST 2: English only (eng)"
        image_eng = RTesseract.new(image_path, lang: 'eng')
        text_eng = image_eng.to_s.strip
        puts "📏 Extracted text length: #{text_eng.length} characters"
        puts "🔤 Text preview: #{text_eng[0..200]}..." if text_eng.length > 0

        # Test 3: Japanese only
        puts "\n📝 TEST 3: Japanese only (jpn)"
        image_jpn = RTesseract.new(image_path, lang: 'jpn')
        text_jpn = image_jpn.to_s.strip
        puts "📏 Extracted text length: #{text_jpn.length} characters"
        puts "🔤 Text preview: #{text_jpn[0..200]}..." if text_jpn.length > 0

        # Choose best result
        results = [
          { config: 'jpn+eng', text: text_jpn_eng },
          { config: 'eng', text: text_eng },
          { config: 'jpn', text: text_jpn }
        ]

        best_result = results.max_by { |r| r[:text].length }

        puts "\n🏆 BEST RESULT: #{best_result[:config]} configuration"
        puts "📏 Length: #{best_result[:text].length} characters"

        if best_result[:text].length > 0
          puts "\n📄 FULL EXTRACTED TEXT:"
          puts "="*40
          puts best_result[:text]
          puts "="*40

          # Test our parsing logic
          puts "\n🧪 Testing schedule parsing..."
          images_data = [{
            url: image_path,
            alt: 'test schedule',
            venue_name: 'Test Venue',
            relevance_score: 10
          }]

          gigs = OcrService.extract_text_from_images(images_data)
          puts "🎯 Parsed #{gigs.count} gigs from text"

          gigs.each_with_index do |gig, i|
            puts "  #{i+1}. #{gig[:date]} - #{gig[:title]}"
            puts "     Venue: #{gig[:venue]}" if gig[:venue]
            puts "     Artists: #{gig[:artists]}" if gig[:artists]
          end
        else
          puts "❌ No text extracted. Possible issues:"
          puts "   • Image quality too low"
          puts "   • Text too small or stylized"
          puts "   • Image contains graphics rather than readable text"
          puts "   • Tesseract language models need adjustment"
        end

      rescue => e
        puts "❌ OCR test failed: #{e.message}"
        puts "🔧 Stack trace: #{e.backtrace.first(3).join("\n")}"
      end
    else
      puts "❌ Sample image not found: #{image_path}"
      puts "\n💡 To test OCR with your schedule image:"
      puts "   1. Save your image as: tmp/sample_schedule.jpg"
      puts "   2. Run: rake venues:test_ocr_sample"
      puts "   3. Or specify path: IMAGE_PATH=/path/to/image.jpg rake venues:test_ocr_sample"
    end

    puts "\n" + "="*50
    puts "OCR SAMPLE TEST COMPLETE!"
    puts "="*50
  end

  desc "Test OCR configuration and show available languages"
  task test_ocr_config: :environment do
    puts "🔧 TESTING OCR CONFIGURATION"
    puts "="*40

    begin
      # Test basic Tesseract functionality
      puts "📋 Tesseract version:"
      system('tesseract --version')

      puts "\n🌍 Available languages:"
      system('tesseract --list-langs')

      puts "\n🧪 Testing basic OCR functionality..."

      # Create a simple test image with text (if ImageMagick is available)
      test_image_path = Rails.root.join('tmp', 'ocr_test.png')

      # Try to create a simple test image
      if system('command -v convert > /dev/null 2>&1')
        puts "🎨 Creating test image with ImageMagick..."
        system("convert -size 400x100 xc:white -font Arial -pointsize 24 -fill black -annotate +10+50 '2025.06.19 Test Event' #{test_image_path}")

        if File.exist?(test_image_path)
          puts "✅ Created test image: #{test_image_path}"

          # Test OCR on the generated image
          image = RTesseract.new(test_image_path.to_s, lang: 'eng')
          result = image.to_s.strip

          puts "📝 OCR result: '#{result}'"

          if result.include?('2025') && result.include?('Test')
            puts "🎉 OCR is working correctly!"
          else
            puts "⚠️  OCR may have issues with text recognition"
          end

          # Cleanup
          File.delete(test_image_path) if File.exist?(test_image_path)
        end
      else
        puts "⚠️  ImageMagick not available - skipping test image creation"
        puts "💡 Install with: brew install imagemagick"
      end

    rescue => e
      puts "❌ OCR configuration test failed: #{e.message}"
    end

    puts "\n✅ OCR configuration test complete!"
  end
end
