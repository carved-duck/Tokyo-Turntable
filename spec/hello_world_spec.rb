require 'spec_helper'

RSpec.describe 'Hello World' do
  it 'says hello' do
    expect("Hello, World!").to eq("Hello, World!")
  end
end