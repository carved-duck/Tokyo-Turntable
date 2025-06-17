namespace :venues do
  desc "Test OCR functionality on image-based schedule venues"
  task test_ocr: :environment do
    puts "🔍 TESTING OCR FUNCTIONALITY"
    puts "="*50

    # Test venues known to have image-based schedules
    test_venues = [
      {
        name: "翠月 (MITSUKI)",
        url: "https://mitsuki-tokyo.com/",
        type: "image_based_schedule"
      }
    ]

    scraper = UnifiedVenueScraper.new(verbose: true)
    total_ocr_gigs = 0
    successful_venues = 0

    test_venues.each_with_index do |venue_config, index|
      puts "\n#{'-'*40}"
      puts "TESTING VENUE #{index + 1}/#{test_venues.count}: #{venue_config[:name]}"
      puts "URL: #{venue_config[:url]}"
      puts "Type: #{venue_config[:type]}"
      puts "#{'-'*40}"

      begin
        # Test the image-based schedule handling directly
        if scraper.is_image_based_schedule_venue?(venue_config[:name], venue_config[:url])
          puts "✅ Detected as image-based schedule venue"

          ocr_gigs = scraper.handle_image_based_schedule_venue(venue_config)

          if ocr_gigs && ocr_gigs.any?
            puts "🎉 OCR SUCCESS: Found #{ocr_gigs.count} gigs!"
            successful_venues += 1
            total_ocr_gigs += ocr_gigs.count

            # Show extracted gigs
            puts "\n📅 Extracted gigs:"
            ocr_gigs.each_with_index do |gig, gig_index|
              puts "  #{gig_index + 1}. #{gig[:date]} - #{gig[:title]}"
            end

            # Test database saving
            begin
              db_result = scraper.send(:save_gigs_to_database, ocr_gigs, venue_config[:name])
              puts "\n💾 Database: #{db_result[:saved]} saved, #{db_result[:skipped]} skipped"
            rescue => e
              puts "\n❌ Database save failed: #{e.message}"
            end
          else
            puts "⚠️  OCR found no gigs"
          end
        else
          puts "❌ Not detected as image-based schedule venue"
        end

      rescue => e
        puts "❌ ERROR: #{e.message}"
        puts "   #{e.backtrace.first(3).join("\n   ")}"
      end

      sleep(2) # Rate limiting
    end

    puts "\n" + "="*50
    puts "OCR TEST COMPLETE!"
    puts "="*50
    puts "✅ Successful venues: #{successful_venues}/#{test_venues.count}"
    puts "📊 Total OCR gigs found: #{total_ocr_gigs}"

    if total_ocr_gigs > 0
      puts "🎉 OCR is working! Found gigs from image-based schedules."
    else
      puts "⚠️  No gigs found. Check:"
      puts "   1. Tesseract is installed (brew install tesseract)"
      puts "   2. Japanese language pack is installed (brew install tesseract-lang)"
      puts "   3. Venue websites have accessible schedule images"
    end
  end

  desc "Install OCR dependencies"
  task install_ocr_deps: :environment do
    puts "🔧 INSTALLING OCR DEPENDENCIES"
    puts "="*40

    # Check if running on macOS
    if RUBY_PLATFORM.include?('darwin')
      puts "📱 macOS detected - using Homebrew for installation"

      # Check if Homebrew is installed
      if system('command -v brew > /dev/null 2>&1')
        puts "✅ Homebrew found"

        # Install Tesseract
        puts "\n📦 Installing Tesseract OCR..."
        if system('brew install tesseract')
          puts "✅ Tesseract installed successfully"
        else
          puts "❌ Failed to install Tesseract"
          exit 1
        end

        # Install Japanese language pack
        puts "\n🇯🇵 Installing Japanese language pack..."
        if system('brew install tesseract-lang')
          puts "✅ Japanese language pack installed successfully"
        else
          puts "⚠️  Failed to install Japanese language pack (may already be included)"
        end

        # Verify installation
        puts "\n🔍 Verifying installation..."
        if system('tesseract --version')
          puts "✅ Tesseract is working!"

          # Check available languages
          puts "\n🌍 Available languages:"
          system('tesseract --list-langs')
        else
          puts "❌ Tesseract verification failed"
        end

      else
        puts "❌ Homebrew not found. Please install Homebrew first:"
        puts "   /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
      end

    else
      puts "🐧 Non-macOS system detected"
      puts "Please install Tesseract manually:"
      puts "  Ubuntu/Debian: sudo apt-get install tesseract-ocr tesseract-ocr-jpn"
      puts "  CentOS/RHEL: sudo yum install tesseract tesseract-langpack-jpn"
      puts "  Other: Check https://github.com/tesseract-ocr/tesseract#installing-tesseract"
    end

    puts "\n✅ OCR dependency installation complete!"
    puts "Now run: bundle install"
    puts "Then test with: rake venues:test_ocr"
  end
end
