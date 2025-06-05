# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @favorited_users = @user.favorites.where(favoritable_type: 'User').map(&:favoritable)
    @favorited_gigs = @user.favorites.where(favoritable_type: 'Gig').map(&:favoritable)
    authorize @user
  end

  def index
    # CRUCIAL FIX: Initialize @users with policy_scope(User) at the very beginning.
    # This ensures Pundit's verify_policy_scoped is satisfied for the index action,
    # regardless of subsequent filtering or redirects.
    @users = policy_scope(User) # Start with all viewable users, scoped by policy.

    # --- SEARCH LOGIC: This section determines if we're processing a search. ---
    if params[:user_query].present?
      # Search within the already-scoped collection
      found_user = @users.find_by("username ILIKE ?", params[:user_query].strip)

      if found_user
        redirect_to user_path(found_user) and return # User found, redirect to their profile.
      else
        # User NOT found:
        # 1. Set a flash message to display at the top of the *next* page load.
        flash[:alert] = "User '#{params[:user_query]}' not found."
        # 2. CRUCIAL: Redirect to a clean URL (/users) to clear the search parameters.
        #    This makes the browser load /users again, ensuring the friends list logic runs
        #    without the search query.
        redirect_to users_path and return # Stops the action here and redirects.
      end
    end
    # --- END SEARCH LOGIC ---

    # --- FILTERING @users for Friends List (only runs if NOT in an active search state) ---
    # If we reach this point, it means params[:user_query] is NOT present in the URL.
    # We now filter the already-scoped @users (which contains all viewable users)
    # to show only the current user's friends.
    if user_signed_in?
      favorited_user_ids = current_user.favorites.where(favoritable_type: 'User').pluck(:favoritable_id)
      @users = @users.where(id: favorited_user_ids)
    else
      # If no user is signed in, @users should be an empty, but still scoped, collection.
      @users = @users.none
    end
    # --- END @users FILTERING ---

    # --- Popular Gigs Logic (MODIFIED to filter by future/current date) ---
    popular_gig_ids_ordered = Favorite.where(favoritable_type: 'Gig')
                                      .group(:favoritable_id)
                                      .order('COUNT(favorites.id) DESC')
                                      .limit(10)
                                      .pluck(:favoritable_id)

    @popular_gigs = []
    if popular_gig_ids_ordered.any?
      order_clause = Arel.sql("CASE gigs.id #{popular_gig_ids_ordered.map.with_index { |id, i| "WHEN #{id} THEN #{i}" }.join(' ')} END")

      # Filter gigs by date to only show future/current shows
      @popular_gigs = Gig.includes(favorites: :user)
                         .where(id: popular_gig_ids_ordered)
                         .where('date >= ?', Date.current) # Filter by current date or future
                         .order(order_clause)
    end
    # --- END Popular Gigs Logic ---
  end
end
