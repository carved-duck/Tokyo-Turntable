class GigsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @gigs = Gig.all
  end

  def show
    @gig = Gig.find(params[:id])
  end

  def edit
  end

  def update
  end

  def destroy

  end
end
