class FavoritesController < ApplicationController
  before_action :authenticate_user! # Ensure only logged-in users can favorite
  before_action :set_favoritable    # Renamed from set_gig to be generic

  def create
    # Ensure a user cannot favorite themselves
    if @favoritable.is_a?(User) && @favoritable == current_user
      redirect_to @favoritable, alert: "You cannot follow yourself!" and return
    end

    current_user.favorite(@favoritable)
    # Authorize the specific action on the @favoritable object
    authorize @favoritable, :favorite?

    # Use a more generic notice based on the favoritable's class name
    redirect_to @favoritable, notice: "#{@favoritable.class.name} favorited!"
  end

 def destroy
    # 1. AUTHORIZE THE ACTION FIRST!
    # Check if the current_user is authorized to unfavorite this @favoritable object.
    # At this point, the favorite record still exists, so user.favorited?(record) will return true.
    authorize @favoritable, :unfavorite?

    # 2. THEN perform the action that modifies the database.
    # The `acts_as_favoritor` gem's unfavorite method requires the favoritable object
    current_user.unfavorite(@favoritable)

    # Use a more generic notice based on the favoritable's class name
    redirect_to @favoritable, notice: "#{@favoritable.class.name} unfavorited."
  end

  private

  # This method now dynamically finds the favoritable object (Gig or User)
  def set_favoritable
    if params[:gig_id].present?
      @favoritable = Gig.find(params[:gig_id])
    elsif params[:user_id].present?
      @favoritable = User.find(params[:user_id])
    else
      # If neither gig_id nor user_id is present, something is wrong with the route/params
      flash[:alert] = "Could not find the item to favorite/unfavorite."
      redirect_back(fallback_location: root_path) and return # Redirect back or to a safe path
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "The requested item could not be found."
    redirect_back(fallback_location: root_path) # Handle case where ID is invalid
  end
end
