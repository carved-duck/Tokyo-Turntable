require 'faker'

# Clear existing data
Attendance.destroy_all
Booking.destroy_all
Gig.destroy_all
Venue.destroy_all
Band.destroy_all
User.destroy_all

users = [
  User.create!(
    email: "will@gmail.com",
    username: "will",
    address: "Tokyo, #{Faker::Address.community}",
    spotify_link: "https://open.spotify.com/user/#{Faker::Internet.username}",
    password: "123456",
    password_confirmation: "123456"
  ),

  User.create!(
    email: "hikari@gmail.com",
    username: "hikari",
    address: "Tokyo, #{Faker::Address.community}",
    spotify_link: "https://open.spotify.com/user/#{Faker::Internet.username}",
    password: "123456",
    password_confirmation: "123456"
  ),

  User.create!(
    email: "ryan@gmail.com",
    username: "ryan",
    address: "Tokyo, #{Faker::Address.community}",
    spotify_link: "https://open.spotify.com/user/#{Faker::Internet.username}",
    password: "123456",
    password_confirmation: "123456"
  ),

  User.create!(
    email: "julian@gmail.com",
    username: "julian",
    address: "Tokyo, #{Faker::Address.community}",
    spotify_link: "https://open.spotify.com/user/#{Faker::Internet.username}",
    password: "123456",
    password_confirmation: "123456"
  )

]

VenueScraper.new.generate_venues
GigImporter.new.import_gigs_from_json
# Create Users
# users = 10.times.map do
#   User.create!(
#     email: Faker::Internet.unique.email,
#     username: Faker::Internet.username,
#     address: "Tokyo, #{Faker::Address.community}",
#     spotify_link: "https://open.spotify.com/user/#{Faker::Internet.username}",
#     password: "password123",
#     password_confirmation: "password123"
#   )
# end

# Create Bands
# genres = ['Rock', 'Indie', 'Jazz', 'Hip-Hop', 'Electronic']
# bands = 10.times.map do
#   Band.create!(
#     name: Faker::Music.band,
#     genre: genres.sample,
#     hometown: Faker::Address.city,
#     email: Faker::Internet.email,
#     spotify_link: "https://open.spotify.com/artist/#{SecureRandom.hex(10)}"
#   )
# end

# # Create Venues
# neighborhoods = ['Shibuya', 'Shinjuku', 'Shimokitazawa', 'Koenji', 'Ikebukuro']
# venues = 5.times.map do
#   Venue.create!(
#     name: "#{Faker::Restaurant.name} Livehouse",
#     address: "Tokyo, #{Faker::Address.street_address}",
#     neighborhood: neighborhoods.sample,
#     website: Faker::Internet.url,
#     email: Faker::Internet.email,
#     details: Faker::Lorem.sentence
#   )
# end



# # Create Gigs
# gigs = 10.times.map do
#   date = Faker::Date.forward(days: 30)
#   open_time = Time.parse("18:00")
#   start_time = Time.parse("19:00")
#   Gig.create!(
#     date: date,
#     open_time: open_time,
#     start_time: start_time,
#     price: rand(1000..3000),
#     venue: venues.sample,
#     user: users.sample
#   )
# end

# # Create Bookings (Bands playing at Gigs)
# gigs.each do |gig|
#   bands.sample(3).each do |band|
#     Booking.create!(gig: gig, band: band)
#   end
# end

# # Create Attendances (Users attending Gigs)
# gigs.each do |gig|
#   users.sample(4).each do |user|
#     Attendance.create!(gig: gig, user: user)
#   end
# end

# puts "Seeded #{User.count} users, #{Band.count} bands, #{Venue.count} venues, #{Gig.count} gigs, #{Booking.count} bookings, and #{Attendance.count} attendances."
