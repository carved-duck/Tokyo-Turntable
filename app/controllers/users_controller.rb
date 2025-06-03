class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    # Fetch favorited gigs for the current user
    @favorited_users = @user.favorites.where(favoritable_type: 'User').map(&:favoritable)
    @favorited_gigs = @user.favorites.where(favoritable_type: 'Gig').map(&:favoritable)
    authorize @user # If you are using Pundit
  end

  def index
    policy_scope(User)
    @users = User.all
  end
end
