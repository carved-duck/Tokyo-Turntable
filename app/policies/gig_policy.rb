class GigPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  def show?
    true # Allows anyone to view a gig
  end

  # This is the method that was missing and causing the error!
  def favorite?
    user.present? # Allows a logged-in user to favorite a gig
  end

  def unfavorite?
    user.present? # Only logged-in users can unfavorite
    # You could add stricter logic here if needed, e.g.,
    # user.present? && user.favorited?(record)
  end

  # You already have create? and destroy? for the FavoritesController's actions
  def create?
    user.present?
  end

  def destroy?
    user.present?
  end

  # You might also need other policy methods if your Gig model has other actions
  # def update?
  #   user.admin? || user == record.user # Example: only admin or gig owner can update
  # end
end
