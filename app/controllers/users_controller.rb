# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @favorited_users = @user.favorites.where(favoritable_type: 'User').map(&:favoritable)
    @favorited_gigs = @user.favorites.where(favoritable_type: 'Gig').map(&:favoritable)
    authorize @user
  end

  def index
    # --- SEARCH LOGIC: This section determines if we're processing a search. ---
    if params[:user_query].present?
      found_user = User.find_by("username ILIKE ?", params[:user_query].strip)

      if found_user
        redirect_to user_path(found_user) and return
      else
        flash[:alert] = "User '#{params[:user_query]}' not found."
        redirect_to users_path and return
      end
    end
    # --- END SEARCH LOGIC ---

    # --- POPULATING @users for Friends List: This block only runs if NOT in an active search state. ---
    if user_signed_in?
      favorited_user_ids = current_user.favorites.where(favoritable_type: 'User').pluck(:favoritable_id)
      @users = policy_scope(User).where(id: favorited_user_ids)
    else
      @users = policy_scope(User).none
    end
    # --- END @users POPULATION ---

    # --- Popular Gigs Logic (MODIFIED to filter by future/current date) ---
    popular_gig_ids_ordered = Favorite.where(favoritable_type: 'Gig')
                                      .group(:favoritable_id)
                                      .order('COUNT(favorites.id) DESC')
                                      .limit(10)
                                      .pluck(:favoritable_id)

    @popular_gigs = []
    if popular_gig_ids_ordered.any?
      order_clause = Arel.sql("CASE gigs.id #{popular_gig_ids_ordered.map.with_index { |id, i| "WHEN #{id} THEN #{i}" }.join(' ')} END")

      # CRUCIAL ADDITION: Filter gigs by date to only show future/current shows
      @popular_gigs = Gig.includes(favorites: :user)
                         .where(id: popular_gig_ids_ordered)
                         .where('date >= ?', Date.current) # Filter by current date or future
                         .order(order_clause)
    end
    # --- END Popular Gigs Logic ---
  end
end
