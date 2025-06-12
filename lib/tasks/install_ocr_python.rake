namespace :venues do
  desc "Install Python OCR dependencies (PaddleOCR and EasyOCR)"
  task install_python_ocr: :environment do
    puts "🐍 INSTALLING PYTHON OCR DEPENDENCIES"
    puts "="*50

    # Check if Python is available
    begin
      stdout, stderr, status = Open3.capture3("python3", "--version")
      if status.success?
        puts "✅ Python3 found: #{stdout.strip}"
      else
        puts "❌ Python3 not found. Please install Python3 first."
        exit 1
      end
    rescue => e
      puts "❌ Error checking Python3: #{e.message}"
      exit 1
    end

    # Check if pip is available
    begin
      stdout, stderr, status = Open3.capture3("pip3", "--version")
      if status.success?
        puts "✅ pip3 found: #{stdout.strip}"
      else
        puts "❌ pip3 not found. Please install pip3 first."
        exit 1
      end
    rescue => e
      puts "❌ Error checking pip3: #{e.message}"
      exit 1
    end

    puts "\n📦 Installing OCR packages..."

    # Install PaddleOCR
    puts "\n🏄 Installing PaddleOCR..."
    begin
      stdout, stderr, status = Open3.capture3("pip3", "install", "paddlepaddle", "paddleocr")
      if status.success?
        puts "✅ PaddleOCR installed successfully"
      else
        puts "⚠️  PaddleOCR installation warning: #{stderr}"
        puts "   (This is often normal - PaddleOCR may still work)"
      end
    rescue => e
      puts "❌ Error installing PaddleOCR: #{e.message}"
    end

    # Install EasyOCR
    puts "\n👁️  Installing EasyOCR..."
    begin
      stdout, stderr, status = Open3.capture3("pip3", "install", "easyocr")
      if status.success?
        puts "✅ EasyOCR installed successfully"
      else
        puts "⚠️  EasyOCR installation warning: #{stderr}"
        puts "   (This is often normal - EasyOCR may still work)"
      end
    rescue => e
      puts "❌ Error installing EasyOCR: #{e.message}"
    end

    # Install additional dependencies
    puts "\n🔧 Installing additional dependencies..."
    begin
      stdout, stderr, status = Open3.capture3("pip3", "install", "opencv-python", "pillow", "numpy")
      if status.success?
        puts "✅ Additional dependencies installed successfully"
      else
        puts "⚠️  Additional dependencies warning: #{stderr}"
      end
    rescue => e
      puts "❌ Error installing additional dependencies: #{e.message}"
    end

    puts "\n🧪 Testing installations..."

    # Test PaddleOCR
    test_script = <<~PYTHON
      try:
          from paddleocr import PaddleOCR
          print("PaddleOCR: SUCCESS")
      except ImportError as e:
          print(f"PaddleOCR: FAILED - {e}")
      except Exception as e:
          print(f"PaddleOCR: ERROR - {e}")

      try:
          import easyocr
          print("EasyOCR: SUCCESS")
      except ImportError as e:
          print(f"EasyOCR: FAILED - {e}")
      except Exception as e:
          print(f"EasyOCR: ERROR - {e}")
    PYTHON

    begin
      temp_script = Tempfile.new(['test_ocr', '.py'])
      temp_script.write(test_script)
      temp_script.close

      stdout, stderr, status = Open3.capture3("python3", temp_script.path)
      puts "📋 Test results:"
      puts stdout

      temp_script.unlink
    rescue => e
      puts "❌ Error testing installations: #{e.message}"
    end

    puts "\n🎉 Installation complete!"
    puts "💡 You can now test with: rake venues:test_multi_ocr"
  end
end
