class BandsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @bands = Band.all
  end

  def show
    @band = Band.find(params[:id])
    authorize @band
  end
end
