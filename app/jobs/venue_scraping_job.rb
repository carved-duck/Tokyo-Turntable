class VenueScrapingJob < ApplicationJob
  queue_as :default

  def perform(options = {})
    Rails.logger.info "🤖 Starting automated venue scraping job"

    # Set up scraper with verbose logging
    scraper = UnifiedVenueScraper.new(
      max_parallel_venues: 2,  # Conservative for background jobs
      verbose: true
    )

    # Run the proven venues first to ensure baseline works
    proven_result = scraper.test_proven_venues_parallel(verbose: true)

    Rails.logger.info "✅ Proven venues scraped: #{proven_result[:successful_venues]} venues, #{proven_result[:total_gigs]} gigs"

    # If proven venues succeed, try some candidate venues
    if proven_result[:successful_venues] >= 4  # At least 4 of our 5 proven venues work
      candidate_result = scraper.ultra_fast_n_plus_one_test(5)  # Test 5 candidates

      Rails.logger.info "🆕 Candidate venues tested: #{candidate_result[:candidate_successful]} new venues found"

      total_gigs = proven_result[:total_gigs] + candidate_result[:total_gigs] - proven_result[:total_gigs]
      Rails.logger.info "📊 Total scraping result: #{total_gigs} gigs found"

      # Send notification if significant new gigs found
      if total_gigs > 40
        Rails.logger.info "🎉 Great scraping session! Found #{total_gigs} gigs"
        # TODO: Add email/Slack notification here
      end

      return {
        success: true,
        proven_venues: proven_result[:successful_venues],
        candidate_venues: candidate_result[:candidate_successful],
        total_gigs: total_gigs
      }
    else
      Rails.logger.error "❌ Baseline proven venues failed, skipping candidate testing"
      return {
        success: false,
        error: "Baseline proven venues failed",
        proven_venues: proven_result[:successful_venues]
      }
    end

  rescue => e
    Rails.logger.error "❌ Venue scraping job failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    return {
      success: false,
      error: e.message
    }
  end
end
