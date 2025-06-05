# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @favorited_users = @user.favorites.where(favoritable_type: 'User').map(&:favoritable)
    @favorited_gigs = @user.favorites.where(favoritable_type: 'Gig').map(&:favoritable)
    authorize @user
  end

  def index
    # This flag controls whether the "My Friends" section should show the actual friends list
    # or be implicitly hidden during a search. Default to true.
    @showing_friends_list = true
    # Initialize @users to an empty policy-scoped collection by default to satisfy Pundit.
    # This will be populated by friends list logic below if no search is active.
    @users = policy_scope(User).none

    # --- NEW SEARCH LOGIC ---
    if params[:user_query].present?
      # When a search query is present, we temporarily stop showing the default friends list
      @showing_friends_list = false

      found_user = User.find_by("username ILIKE ?", params[:user_query].strip)

      if found_user
        redirect_to user_path(found_user) and return # Redirect if user found
      else
        # --- CRITICAL FIX HERE: Use `flash` and `redirect_to` to clear the URL ---
        flash[:alert] = "User '#{params[:user_query]}' not found."
        redirect_to users_path and return # Redirect back to /users to clear query params
      end
    else
      # --- Existing MODIFIED LOGIC for @users (Friends list) when no search query is present ---
      # This block now ONLY executes if there is NO search query (clean URL).
      if user_signed_in?
        @users = policy_scope(User).where(id: current_user.favorites.where(favoritable_type: 'User').pluck(:favoritable_id))
      end
    end
    # --- END MODIFIED LOGIC for @users ---

    # Original popular gigs logic remains untouched
    popular_gig_ids_ordered = Favorite.where(favoritable_type: 'Gig')
                                      .group(:favoritable_id)
                                      .order('COUNT(favorites.id) DESC')
                                      .limit(10)
                                      .pluck(:favoritable_id)

    @popular_gigs = []
    if popular_gig_ids_ordered.any?
      order_clause = Arel.sql("CASE gigs.id #{popular_gig_ids_ordered.map.with_index { |id, i| "WHEN #{id} THEN #{i}" }.join(' ')} END")
      @popular_gigs = Gig.includes(favorites: :user)
                         .where(id: popular_gig_ids_ordered)
                         .order(order_clause)
    end
  end
end
