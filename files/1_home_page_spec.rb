require "rails_helper"

feature "The home page" do
  it "displays a greeting", points: 1, hint: I18n.t("hints.greeting") do
    visit "/"

    expect(page).to have_css("p", text: "hi")
  end
end
