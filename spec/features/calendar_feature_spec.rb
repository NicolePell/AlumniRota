require 'capybara/rspec'
require 'spec_helper'

feature 'Calendar' do
  scenario 'it should display on the homepage' do
    visit '/'
    expect(page.status_code).to eq 200
  end
end
