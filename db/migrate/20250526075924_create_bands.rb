class CreateBands < ActiveRecord::Migration[7.1]
  def change
    create_table :bands do |t|
      t.string :name
      t.string :genre
      t.string :hometown
      t.string :website_link
      t.string :email
      t.string :spotify_link

      t.timestamps
    end
  end
end
