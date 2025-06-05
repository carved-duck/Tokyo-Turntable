# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @favorited_users = @user.favorites.where(favoritable_type: 'User').map(&:favoritable)
    @favorited_gigs = @user.favorites.where(favoritable_type: 'Gig').map(&:favoritable)
    authorize @user
  end

  def index
    # Initialize @users for Pundit, default to empty
    @users = policy_scope(User).none

    # --- SEARCH LOGIC ---
    if params[:user_query].present?
      found_user = User.find_by("username ILIKE ?", params[:user_query].strip)

      if found_user
        redirect_to user_path(found_user) and return
      else
        flash[:alert] = "User '#{params[:user_query]}' not found."
        redirect_to users_path and return
      end
    else
      # --- Friends list logic when NO search query is present ---
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
