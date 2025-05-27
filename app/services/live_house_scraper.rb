class LiveHouseScraper
  require 'open-uri'
  require 'nokogiri'
  require 'json'

  def scrape_tokyo_venues
    # Getting gigs just from the first page
    gigs_url = "https://www.tokyogigguide.com/en/gigs"

    page_html_file = URI.parse(gigs_url).read
    page_html_doc = Nokogiri::HTML.parse(page_html_file)

    gigs = page_html_doc.search('.eventlist li').map do |gig_card|
      gig_data = {}
      gig_data['name'] = gig_card.search('.jem-event-details h4').text.strip
      gig_card.search('.jem-event-info').each do |info_item|
        info_string = info_item.attribute("title").value
        key, value = info_string.split(': ')
        date, time = value.scan(/(\w{3} \d{1,2}) \(\w{3}\)(\d{2}\.\d{2})/).flatten
        if date || time
          gig_data['open_time'] = time unless time.nil?
          gig_data['date'] = date unless date.nil?
        else
          gig_data[key.downcase.gsub(/\W+/, '_')] = value
        end
      end
      gig_data
    end

    # saving to a json file
    filepath = "./db/data/gigs.json"
    File.open(filepath, "wb") do |file|
      file.write(JSON.generate({data: gigs}))
    end
  end
end
