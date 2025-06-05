# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @favorited_users = @user.favorites.where(favoritable_type: 'User').map(&:favoritable)
    @favorited_gigs = @user.favorites.where(favoritable_type: 'Gig').map(&:favoritable)
    authorize @user
  end

  def index
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

    # --- MODIFIED LOGIC for @users (Friends list) ---
    # First, apply Pundit's policy scope to get all users the current_user is allowed to see.
    all_viewable_users = policy_scope(User)

    if user_signed_in?
      # If signed in, get the IDs of users that the current_user has favorited (friends).
      favorited_user_ids = current_user.favorites.where(favoritable_type: 'User').pluck(:favoritable_id)

      # Filter the *policy-scoped* users by these favorited IDs.
      @users = all_viewable_users.where(id: favorited_user_ids)
    else
      # If no user is signed in, show an empty list of users.
      # Using .none on the policy-scoped collection ensures Pundit's checks are satisfied.
      @users = all_viewable_users.none
    end
    # --- END MODIFIED LOGIC ---
  end
end
