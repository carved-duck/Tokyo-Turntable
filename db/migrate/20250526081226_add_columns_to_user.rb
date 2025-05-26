class AddColumnsToUser < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :username, :string
    add_column :users, :address, :string
    add_reference :users, :band, null: false, foreign_key: true
    add_column :users, :spotify_link, :string
    add_column :users, :discogs_link, :string
    add_column :users, :past_shows, :string
  end
end
