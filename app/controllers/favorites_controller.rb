class FavoritesController < ApplicationController
  before_action :authenticate_user! # Ensure only logged-in users can favorite
  before_action :set_gig # Find the gig associated with the favorite action

  def create
    current_user.favorite(@gig)
     authorize @gig, :favorite? # If you use Pundit, you'd authorize here

    redirect_to @gig, notice: "Gig favorited!"
    # Or render a JS response for AJAX
  end

  def destroy
    current_user.unfavorite(@gig)
    authorize @gig, :unfavorite? # If you use Pundit

    redirect_to @gig, notice: "Gig unfavorited."
    # Or render a JS response for AJAX
  end

  private

  def set_gig
    @gig = Gig.find(params[:gig_id])
  end
end
