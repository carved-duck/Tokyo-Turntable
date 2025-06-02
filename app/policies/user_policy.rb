# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  def show?
    user == record
  end

  def profile?
    user == record
  end

  def index?
    user == record
  end
end
