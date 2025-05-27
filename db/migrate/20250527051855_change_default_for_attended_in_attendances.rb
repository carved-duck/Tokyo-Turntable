class ChangeDefaultForAttendedInAttendances < ActiveRecord::Migration[7.1]
  def change
    change_column_default :attendances, :attended, from: nil, to: false
  end
end
