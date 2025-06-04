# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @favorited_users = @user.favorites.where(favoritable_type: 'User').map(&:favoritable)
    @favorited_gigs = @user.favorites.where(favoritable_type: 'Gig').map(&:favoritable)
    authorize @user
  end

  def index
    @users = policy_scope(User)

    # Step 1: Find the IDs of the top N most favorited gigs
    # This query runs against the `favorites` table.
    popular_gig_ids_ordered = Favorite.where(favoritable_type: 'Gig')
                                      .group(:favoritable_id) # Group by the ID of the gig
                                      .order('COUNT(favorites.id) DESC') # Order by favorite count (most popular first)
                                      .limit(10) # Get the top 10 (adjust as needed)
                                      .pluck(:favoritable_id) # Extract only the gig IDs in that order

    # Initialize @popular_gigs as an empty array if no gigs are found (important for view)
    @popular_gigs = []

    if popular_gig_ids_ordered.any?
      # Step 2: Fetch the actual Gig objects using the IDs obtained in Step 1.
      # Now we can use `includes` without the GROUP BY conflict, as we are querying Gig directly by ID.
      # We also ensure the order matches the popularity ranking from Step 1.
      # Arel.sql is used for PostgreSQL to order by a specific list of IDs.
      order_clause = Arel.sql("CASE gigs.id #{popular_gig_ids_ordered.map.with_index { |id, i| "WHEN #{id} THEN #{i}" }.join(' ')} END")

      @popular_gigs = Gig.includes(favorites: :user) # Eager load favorites and their associated users
                         .where(id: popular_gig_ids_ordered) # Filter by the top N gig IDs
                         .order(order_clause) # Apply the custom order to maintain popularity ranking
    end
  end
end
