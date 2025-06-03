# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  def show?
    true
  end

  def profile?
    user == record
  end

   def favorite?
    # A user can favorite another user if they are logged in and not trying to favorite themselves
    user.present? && user != record
  end

  def unfavorite?
    # A user can unfavorite another user if they are logged in and have previously favorited them
    user.present? && user != record && user.favorited?(record)
  end

end
