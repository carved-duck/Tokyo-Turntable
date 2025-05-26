class CreateGigs < ActiveRecord::Migration[7.1]
  def change
    create_table :gigs do |t|
      t.date :date
      t.references :venue, null: false, foreign_key: true
      t.string :open_time
      t.string :start_time
      t.string :price
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
