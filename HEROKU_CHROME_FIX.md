# Heroku Chrome Configuration & Scraper Fixes

## 🚨 **Critical Heroku Issues Fixed**

Your Heroku deployment was failing because:

1. **Chrome Binary Path Issue**: Trying to use macOS Chrome paths on Linux Heroku
2. **Invalid URL Scraping**: Attempting to scrape "Not Listed" as actual URLs
3. **Missing Chrome Buildpacks**: No Chrome/ChromeDriver installation

## ✅ **Solutions Implemented**

### 1. Environment-Aware Chrome Configuration
- **Added**: Automatic detection of Heroku vs local environment
- **Fixed**: Browser creation now uses system Chrome on Heroku, local paths in development
- **Location**: `app/services/unified_venue_scraper.rb` & `app/services/base_scraper.rb`

```ruby
def heroku_environment?
  ENV['DYNO'].present? || ENV['HEROKU_APP_NAME'].present? ||
  Rails.env.production? && ENV['DATABASE_URL']&.include?('postgres')
end
```

### 2. Heroku Buildpack Configuration
- **Created**: `app.json` with required buildpacks
- **Created**: `.buildpacks` file for buildpack order
- **Buildpacks**: Google Chrome + ChromeDriver + Ruby

**Required buildpacks (in order):**
1. `heroku-buildpack-google-chrome`
2. `heroku-buildpack-chromedriver`
3. `heroku/ruby`

### 3. Invalid URL Filtering
- **Fixed**: "Not Listed" URLs now filtered out before scraping
- **Added**: Proper HTTP/HTTPS URL validation
- **Location**: Both `ultra_fast` and `heroku` scrapers

## 🛠️ **Deployment Instructions**

### For New Heroku App:
```bash
# Set buildpacks in correct order
heroku buildpacks:clear
heroku buildpacks:add https://github.com/heroku/heroku-buildpack-google-chrome
heroku buildpacks:add https://github.com/heroku/heroku-buildpack-chromedriver
heroku buildpacks:add heroku/ruby

# Deploy
git push heroku main
```

### For Existing Heroku App:
```bash
# Check current buildpacks
heroku buildpacks

# If incorrect order, clear and re-add
heroku buildpacks:clear
heroku buildpacks:add https://github.com/heroku/heroku-buildpack-google-chrome
heroku buildpacks:add https://github.com/heroku/heroku-buildpack-chromedriver
heroku buildpacks:add heroku/ruby

# Push changes
git push heroku main
```

## 🔧 **Environment Variables** (Optional)
These are set automatically by buildpacks, but you can verify:
```bash
heroku config:set CHROME_BIN=/app/.chrome-for-testing/chrome-linux64/chrome
heroku config:set CHROMEDRIVER_PATH=/app/.chrome-for-testing/chromedriver-linux64/chromedriver
```

## 📊 **Expected Results**

### Before Fix:
- ❌ Chrome browser creation failed
- ❌ "Not Listed" URI errors
- ❌ 4.1% success rate

### After Fix:
- ✅ Chrome works on both Heroku and local
- ✅ Invalid URLs filtered out
- ✅ Expected ~35% success rate
- ✅ Clean error handling

## 🧪 **Testing the Fix**

### Test Locally:
```bash
rails scrape:ultra_fast
```

### Test on Heroku:
```bash
heroku run rails scrape:heroku
```

## 📝 **Notes**

1. **No Code Changes Needed**: Environment detection is automatic
2. **Same Logic**: Both scrapers use identical scraping logic
3. **Better Filtering**: Excludes invalid/social media URLs
4. **Heroku Optimized**: Conservative parallelism for memory limits

## 🔍 **Troubleshooting**

If Chrome still fails on Heroku:
1. Check buildpack order: `heroku buildpacks`
2. Verify Chrome installation: `heroku run which google-chrome`
3. Check Chrome process: `heroku run google-chrome --version`
4. Review logs: `heroku logs --tail`

The system will automatically fall back to system-managed drivers if the configured paths fail.
