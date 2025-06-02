# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      puts "--- UserPolicy::Scope#resolve called ---" # Debug
      scope.all
    end
  end

  def show?
    puts "--- UserPolicy#show? called ---" # Debug
    puts "  Policy 'user' object: #{user.inspect}" # Debug
    puts "  Policy 'record' object: #{record.inspect}" # Debug
    puts "  Comparison (user == record): #{user == record}" # Debug
    user == record
  end

  # ADD THIS METHOD:
  def profile?
    puts "--- UserPolicy#profile? called ---" # Debug
    puts "  Policy 'user' object: #{user.inspect}" # Debug
    puts "  Policy 'record' object: #{record.inspect}" # Debug
    puts "  Comparison (user == record): #{user == record}" # Debug
    user == record
  end
end
