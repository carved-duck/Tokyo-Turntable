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

end
