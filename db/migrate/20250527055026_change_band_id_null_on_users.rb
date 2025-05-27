class ChangeBandIdNullOnUsers < ActiveRecord::Migration[7.1]
  def change
    change_column_null :users, :band_id, true
  end
end
