require 'test_helper'

class VenueNavigatorTest < ActiveSupport::TestCase
  def setup
    @venues = {
      den_atsu: {
        'name' => 'Den-Atsu',
        'website' => 'https://den-atsu.com'
      },
      antiknock: {
        'name' => 'Antiknock',
        'website' => 'https://antiknock.net'
      },
      milkyway: {
        'name' => 'Shibuya Milkyway',
        'website' => 'https://www.shibuyamilkyway.com'
      },
      yokohama_arena: {
        'name' => 'Yokohama Arena',
        'website' => 'https://www.yokohama-arena.co.jp'
      }
    }
  end

  test "finds event pages for Den-Atsu" do
    navigator = VenueNavigator.new(@venues[:den_atsu])
    pages = navigator.find_event_pages
    assert_not_empty pages
    assert pages.all? { |url| url.include?('den-atsu.com') }
  end

  test "finds event pages for Antiknock" do
    navigator = VenueNavigator.new(@venues[:antiknock])
    pages = navigator.find_event_pages
    assert_not_empty pages
    assert pages.all? { |url| url.include?('antiknock.net') }
  end

  test "finds event pages for Shibuya Milkyway" do
    navigator = VenueNavigator.new(@venues[:milkyway])
    pages = navigator.find_event_pages
    assert_not_empty pages
    assert pages.all? { |url| url.include?('shibuyamilkyway.com') }
    assert pages.any? { |url| url.include?('/new/SCHEDULE/') }
  end

  test "finds event pages for Yokohama Arena" do
    navigator = VenueNavigator.new(@venues[:yokohama_arena])
    pages = navigator.find_event_pages
    assert_not_empty pages
    assert pages.all? { |url| url.include?('yokohama-arena.co.jp') }
  end

  test "handles invalid website URLs" do
    invalid_venue = { 'name' => 'Invalid Venue', 'website' => nil }
    navigator = VenueNavigator.new(invalid_venue)
    pages = navigator.find_event_pages
    assert_empty pages
  end
end
