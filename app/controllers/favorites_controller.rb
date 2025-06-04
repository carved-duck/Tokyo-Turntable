class FavoritesController < ApplicationController
  before_action :authenticate_user! # Ensure only logged-in users can favorite
  before_action :set_favoritable    # Renamed from set_gig to be generic

  def create

    if @favoritable.is_a?(User) && @favoritable == current_user
      flash[:alert] = "You cannot follow yourself!"
      redirect_to @favoritable
      skip_authorization
      return
    end

    authorize @favoritable, :favorite?
    current_user.favorite(@favoritable)

    redirect_to @favoritable, notice: "#{@favoritable.class.name} favorited!"
  end


 def destroy
    authorize @favoritable, :unfavorite?
    current_user.unfavorite(@favoritable)
    redirect_to @favoritable, notice: "#{@favoritable.class.name} unfavorited."
 end

  private

  def set_favoritable
    if params[:gig_id].present?
      @favoritable = Gig.find(params[:gig_id])
    elsif params[:user_id].present?
      @favoritable = User.find(params[:user_id])
    else
      flash[:alert] = "Could not find the item to favorite/unfavorite."
      redirect_back(fallback_location: root_path) and return
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "The requested item could not be found."
    redirect_back(fallback_location: root_path) # Handle case where ID is invalid
  end
end
