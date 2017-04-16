require "rails_helper"

feature "The home page" do
  it "displays a greeting", points: 1, hint: "Should say hi" do
    visit "/"

    expect(page).to have_selector("p", text: "hi")
  end
end
