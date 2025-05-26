class CreateAttendances < ActiveRecord::Migration[7.1]
  def change
    create_table :attendances do |t|
      t.references :gig, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :attended

      t.timestamps
    end
  end
end
