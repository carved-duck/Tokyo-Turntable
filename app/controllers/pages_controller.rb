class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def index
  end

  def home
    if params[:date].present? || params[:genres].present?
      gigs = Gig.where(date: params[:date]) if params[:date].present?
    unless params[:genres] == ""
      params[:genres].split(", ").each do |genre|
        gigs = gigs.reject{ |gig| !gig.bands.map(&:genre).uniq.include?(genre) }
      end
    end
      @count = gigs.count
    else
      @count = Gig.count
    end
    respond_to do |format|
      format.html
      format.json # Follows the classic Rails flow and look for a create.json view
    end
  end
end
