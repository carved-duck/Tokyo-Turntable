class UsersController < ApplicationController
  def profile
    @user = current_user
    # Fetch favorited gigs for the current user
    @favorited_gigs = @user.favorited_by_type('Gig')
    # Or, if you want all favorited items regardless of type:
    # @all_favorited_items = @user.all_favorited
    authorize @user # If you are using Pundit
  end

  # use this as example for profile then delete after.
  #   def dashboard
  #   @rentals = current_user.rentals
  #   @tools = current_user.tools
  #   @rentals_as_owner = current_user.rentals_as_owner
  #   @pending_approvals = @rentals_as_owner.where(status: "pending")
  #   @waiting_for_return = @rentals_as_owner.where(status: "accepted")
  #   @my_pending = @rentals.where(status: "pending")
  #   @my_accepted = @rentals.where(status: "accepted")
  # end
end
