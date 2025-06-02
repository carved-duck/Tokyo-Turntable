class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    # Fetch favorited gigs for the current user
    @favorited_gigs = @user.favorited_by_type('Gig')
    # Or, if you want all favorited items regardless of type:
    # @all_favorited_items = @user.all_favorited
    authorize @user # If you are using Pundit
  end

  def index
    policy_scope(User)
    @users = User.all
  end
end
