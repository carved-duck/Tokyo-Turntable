class Venue < ApplicationRecord
  has_many :gigs

  has_one_attached :photo

  validates :name, presence: true
  validates :address, presence: true
  validates :email, presence: true
  validates :neighborhood, presence: true
  validates :details, presence: true

  geocoded_by :enhanced_address
  after_validation :geocode_with_fallback, if: :will_save_change_to_address?

  # 🇯🇵 Enhanced address for better geocoding accuracy
  def enhanced_address
    return nil if address.blank? || address == "Not Available"

    # If address already contains Japan/Tokyo context, use as-is
    return address if address.match?(/japan|日本|東京都|tokyo/i)

    # Enhance incomplete addresses
    enhanced = address.dup

    # Add Tokyo context if missing
    unless enhanced.match?(/tokyo|東京|渋谷区|新宿区|港区|千代田区|品川区|目黒区|世田谷区|中野区|杉並区|豊島区|北区|荒川区|板橋区|練馬区|足立区|葛飾区|江戸川区|台東区|墨田区|江東区|大田区/i)
      enhanced += ", Tokyo"
    end

    # Add Japan context
    enhanced += ", Japan" unless enhanced.match?(/japan|日本/i)

    enhanced
  end

  # 🗺️ Fallback geocoding using neighborhood coordinates
  def geocode_with_fallback
    # First try normal geocoding
    geocode

    # If geocoding failed or coordinates are outside Japan, use neighborhood fallback
    if latitude.blank? || longitude.blank? || !coordinates_in_japan?
      fallback_coordinates = neighborhood_coordinates
      if fallback_coordinates
        self.latitude = fallback_coordinates[:lat]
        self.longitude = fallback_coordinates[:lng]
        Rails.logger.info "🗺️ Used neighborhood fallback for #{name}: #{neighborhood}"
      end
    end
  end

  acts_as_favoritable # Allows gigs to be followed/favorited by others

  include PgSearch::Model
  pg_search_scope :global_search,
  against: [ :name, :address, :neighborhood ],
  using: {
    tsearch: { prefix: true }
  }

  def next_show
    gigs.where("date > ?", Time.current).order(:date).first
  end

  private

  def coordinates_in_japan?
    return false if latitude.blank? || longitude.blank?
    # Japan bounds - allow venues anywhere in Japan for accuracy
    latitude.between?(31.0, 46.0) && longitude.between?(129.0, 146.0)
  end

      # 📍 Neighborhood coordinate mapping for accurate venue locations across Japan
  def neighborhood_coordinates
    neighborhood_map = {
      # Central Tokyo
      'Shibuya' => { lat: 35.6598, lng: 139.7006 },
      'Shinjuku' => { lat: 35.6896, lng: 139.6917 },
      'Harajuku' => { lat: 35.6702, lng: 139.7026 },
      'Roppongi' => { lat: 35.6627, lng: 139.7314 },
      'Ginza' => { lat: 35.6762, lng: 139.7653 },
      'Akihabara' => { lat: 35.7022, lng: 139.7749 },
      'Ueno' => { lat: 35.7141, lng: 139.7774 },
      'Asakusa' => { lat: 35.7148, lng: 139.7967 },
      'Ikebukuro' => { lat: 35.7295, lng: 139.7109 },
      'Yurakucho' => { lat: 35.6751, lng: 139.7634 },
      'Nihonbashi' => { lat: 35.6833, lng: 139.7731 },
      'Marunouchi' => { lat: 35.6813, lng: 139.7660 },

      # West Tokyo
      'Shimokitazawa' => { lat: 35.6613, lng: 139.6683 },
      'Kichijoji' => { lat: 35.7022, lng: 139.5803 },
      'Koenji' => { lat: 35.7058, lng: 139.6489 },
      'Nakano' => { lat: 35.7056, lng: 139.6657 },
      'Ogikubo' => { lat: 35.7058, lng: 139.6201 },
      'Asagaya' => { lat: 35.7058, lng: 139.6364 },
      'Suginami' => { lat: 35.6993, lng: 139.6365 },
      'Setagaya' => { lat: 35.6464, lng: 139.6533 },

      # East Tokyo
      'Sumida' => { lat: 35.7101, lng: 139.8107 },
      'Koto' => { lat: 35.6717, lng: 139.8171 },
      'Edogawa' => { lat: 35.7068, lng: 139.8686 },

      # South Tokyo
      'Meguro' => { lat: 35.6339, lng: 139.7157 },
      'Shinagawa' => { lat: 35.6284, lng: 139.7387 },
      'Ota' => { lat: 35.5617, lng: 139.7161 },
      'Ebisu' => { lat: 35.6467, lng: 139.7100 },
      'Daikanyama' => { lat: 35.6496, lng: 139.6993 },

      # North Tokyo
      'Uguisudani' => { lat: 35.7214, lng: 139.7781 },
      'Nippori' => { lat: 35.7281, lng: 139.7714 },
      'Tabata' => { lat: 35.7381, lng: 139.7606 },
      'Komagome' => { lat: 35.7364, lng: 139.7472 },

      # Greater Tokyo Area
      'Yokohama' => { lat: 35.4437, lng: 139.6380 },
      'Sakuragicho' => { lat: 35.4508, lng: 139.6317 },
      'Minato Mirai' => { lat: 35.4560, lng: 139.6311 },
      'Kawasaki' => { lat: 35.5308, lng: 139.7029 },

      # Chiba Prefecture
      'Chiba' => { lat: 35.6074, lng: 140.1065 },
      'Funabashi' => { lat: 35.6947, lng: 139.9836 },
      'Kashiwa' => { lat: 35.8617, lng: 139.9753 },
      'Makuhari' => { lat: 35.6490, lng: 140.0333 },

      # Saitama Prefecture
      'Saitama' => { lat: 35.8617, lng: 139.6455 },
      'Omiya' => { lat: 35.9067, lng: 139.6233 },
      'Urawa' => { lat: 35.8617, lng: 139.6455 },

      # Kanagawa Prefecture
      'Kamakura' => { lat: 35.3194, lng: 139.5519 },
      'Fujisawa' => { lat: 35.3394, lng: 139.4889 },
      'Odawara' => { lat: 35.2561, lng: 139.1608 },
      'Yokosuka' => { lat: 35.2806, lng: 139.6717 },

      # Other Major Cities (for venues that might be legitimately outside Tokyo)
      'Osaka' => { lat: 34.6937, lng: 135.5023 },
      'Kyoto' => { lat: 35.0116, lng: 135.7681 },
      'Nagoya' => { lat: 35.1815, lng: 136.9066 },
      'Sendai' => { lat: 38.2682, lng: 140.8694 },
      'Hiroshima' => { lat: 34.3853, lng: 132.4553 },
      'Fukuoka' => { lat: 33.5904, lng: 130.4017 },

      # Default Tokyo center for unknown neighborhoods
      'Tokyo' => { lat: 35.6762, lng: 139.6503 }
    }

    # Try exact match first
    coords = neighborhood_map[neighborhood]
    return coords if coords

    # Try partial matches
    neighborhood_map.each do |area, coords|
      if neighborhood&.include?(area) || area.include?(neighborhood.to_s)
        return coords
      end
    end

    # Default to Tokyo center
    neighborhood_map['Tokyo']
  end
end
