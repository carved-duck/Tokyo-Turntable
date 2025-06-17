namespace :scraping do
  desc "Run automated venue scraping (background job)"
  task auto: :environment do
    puts "🤖 Enqueuing automated venue scraping job with Solid Queue..."

    job = VenueScrapingJob.perform_later
    puts "✅ Job enqueued with ID: #{job.job_id}"
    puts "📊 Job will run in background and save results to database"
    puts ""
    puts "To check job status:"
    puts "  rails runner \"puts 'Pending: ' + SolidQueue::Job.where(finished_at: nil).count.to_s\""
    puts "  rails runner \"puts 'Completed: ' + SolidQueue::Job.where.not(finished_at: nil).count.to_s\""
    puts ""
    puts "To run immediately instead:"
    puts "  rails scraping:auto_now"
    puts ""
    puts "To start the worker (if not running):"
    puts "  bundle exec rake solid_queue:start"
  end

  desc "Run automated venue scraping immediately (foreground)"
  task auto_now: :environment do
    puts "🤖 Running automated venue scraping immediately..."

    result = VenueScrapingJob.new.perform

    if result[:success]
      puts "\n🎉 AUTOMATED SCRAPING COMPLETED SUCCESSFULLY!"
      puts "✅ Proven venues: #{result[:proven_venues]}"
      puts "🆕 New venues: #{result[:candidate_venues] || 0}"
      puts "📊 Total gigs found: #{result[:total_gigs]}"

      # Check database
      total_db_gigs = Gig.count
      puts "💾 Database now contains: #{total_db_gigs} total gigs"
    else
      puts "\n❌ AUTOMATED SCRAPING FAILED"
      puts "Error: #{result[:error]}"
      puts "Proven venues working: #{result[:proven_venues] || 0}"
    end
  end

  desc "Test database integration with a quick scrape"
  task test_db: :environment do
    puts "🧪 Testing database integration with quick proven venue scrape..."

    # Check initial state
    initial_gigs = Gig.count
    puts "📊 Initial gigs in database: #{initial_gigs}"

    # Run quick test
    scraper = UnifiedVenueScraper.new(verbose: true)
    result = scraper.test_proven_venues

    # Check final state
    final_gigs = Gig.count
    new_gigs = final_gigs - initial_gigs

    puts "\n📊 RESULTS:"
    puts "✅ Venues scraped: #{result[:successful_venues]}"
    puts "📈 Gigs found: #{result[:total_gigs]}"
    puts "💾 New gigs in database: #{new_gigs}"
    puts "📊 Total gigs in database: #{final_gigs}"

    if new_gigs > 0
      puts "\n🎉 Database integration working!"
      puts "Sample new gigs:"
      Gig.order(created_at: :desc).limit(3).each do |gig|
        puts "  📅 #{gig.date} at #{gig.venue.name} - #{gig.open_time}"
      end
    else
      puts "\n⚠️  No new gigs added (might be duplicates)"
    end
  end

  desc "Show Solid Queue job status"
  task status: :environment do
    puts "📊 SOLID QUEUE JOB STATUS"
    puts "="*50
    puts ""

    total_jobs = SolidQueue::Job.count
    pending_jobs = SolidQueue::Job.where(finished_at: nil).count
    completed_jobs = SolidQueue::Job.where.not(finished_at: nil).count
    failed_jobs = SolidQueue::FailedExecution.count

    puts "📈 Total jobs: #{total_jobs}"
    puts "⏳ Pending jobs: #{pending_jobs}"
    puts "✅ Completed jobs: #{completed_jobs}"
    puts "❌ Failed jobs: #{failed_jobs}"
    puts ""

    if pending_jobs > 0
      puts "🔄 PENDING JOBS:"
      SolidQueue::Job.where(finished_at: nil).limit(5).each do |job|
        puts "  • #{job.class_name} (ID: #{job.id}) - #{job.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
      end
      puts ""
    end

    if failed_jobs > 0
      puts "❌ RECENT FAILED JOBS:"
      SolidQueue::FailedExecution.limit(3).each do |failed|
        puts "  • #{failed.job.class_name} - #{failed.error}"
      end
      puts ""
    end

    puts "💡 COMMANDS:"
    puts "  Start worker: bundle exec rake solid_queue:start"
    puts "  Enqueue job: rails scraping:auto"
    puts "  Run immediately: rails scraping:auto_now"
  end

  desc "Show scraping schedule suggestions"
  task schedule: :environment do
    puts "⏰ AUTOMATED SCRAPING SCHEDULE WITH SOLID QUEUE"
    puts "="*60
    puts ""
    puts "🎯 SOLID QUEUE SETUP COMPLETE!"
    puts "✅ Background job system: Solid Queue"
    puts "✅ Recurring jobs configured for production"
    puts "✅ Database tables created"
    puts ""
    puts "📅 PRODUCTION SCHEDULE (automatic):"
    puts "  • 6:00 AM daily - Morning venue scraping"
    puts "  • 6:00 PM daily - Evening venue scraping"
    puts ""
    puts "🚀 HEROKU DEPLOYMENT:"
    puts "  • Procfile configured with worker process"
    puts "  • Scale worker: heroku ps:scale worker=1"
    puts "  • Check logs: heroku logs --tail -p worker"
    puts ""
    puts "🔧 LOCAL DEVELOPMENT:"
    puts "  • Start worker: bundle exec rake solid_queue:start"
    puts "  • Test job: rails scraping:auto"
    puts "  • Check status: rails scraping:status"
    puts ""
    puts "📊 MONITORING:"
    puts "  • Job status: rails scraping:status"
    puts "  • Database count: rails runner 'puts Gig.count'"
    puts "  • Recent gigs: rails runner 'Gig.order(created_at: :desc).limit(5).each { |g| puts g.date }'"
    puts ""
    puts "🎛️  MANUAL TRIGGER:"
    puts "  rails scraping:auto_now"
    puts ""
    puts "✨ BENEFITS OF SOLID QUEUE:"
    puts "  • No Redis dependency (uses PostgreSQL)"
    puts "  • Heroku-friendly (no additional services)"
    puts "  • Built-in Rails integration"
    puts "  • Automatic recurring jobs"
    puts "  • Job monitoring and retry capabilities"
  end
end
