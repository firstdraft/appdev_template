# Helper methods to copy in files
# ===============================

# TODO: Switch to pg from sqlite

ENV = :prod
# ENV = :dev

def path_to_file(filename)
  if ENV == :prod
    "https://raw.githubusercontent.com/firstdraft/appdev_template/master/#{filename}"
  else
    File.join(File.expand_path(File.dirname(__FILE__)), "files", filename)
  end
end

def path_to_blob(filename)
  "https://raw.githubusercontent.com/firstdraft/appdev_template/master/files/#{filename}"
end

def render_file(filename)
  if ENV == :prod
    require "open-uri"

    begin
      open(path_to_file(filename)).read
    rescue
      open(path_to_blob(filename)).read
    end
  else
    IO.read(path_to_file(filename))
  end
end

skip_active_admin = yes?("Skip ActiveAdmin?")
skip_devise = yes?("Skip Devise?")

# Add standard gems
# =================

gem_group :development, :test do
  gem "dotenv-rails"
  gem "pry-rails"
  gem "grade_runner", github: "firstdraft/grade_runner"
  gem "web_git", github: "firstdraft/web_git"
end

gem_group :development do
  gem "annotate"
  gem "awesome_print"
  gem "better_errors"
  gem "firstdraft_debugger", git: "https://github.com/firstdraft/firstdraft_debugger.git"
  gem "web-console"
  gem "binding_of_caller"
  gem "firstdraft_generators", github: "firstdraft/firstdraft_generators"
  gem "letter_opener"
  gem "meta_request"
  gem "wdm", platforms: [:mingw, :mswin, :x64_mingw]
end

gem_group :test do
  gem "capybara"
  gem "factory_girl_rails"
  gem "rspec-rails"
  gem "webmock"
end

gem "activeadmin", github: "activeadmin/activeadmin" unless skip_active_admin
# gem "bootstrap-sass"
gem "devise", github: "plataformatec/devise" unless skip_devise
gem "jquery-rails"
# gem "font-awesome-sass", "~> 4.7.0"

# Use WEBrick

# gsub_file "Gemfile",
#   /gem 'puma'/,
#   "# gem 'puma'"

after_bundle do
  # Copy circle.yml

  file "circle.yml", render_file("circle.yml")

  # Overwrite bin/setup

  remove_file "bin/setup"
  file "bin/setup", render_file("setup")

  # Add dev:prime task

  file "lib/tasks/dev.rake", render_file("dev.rake")

  # Add bin/server

  file "bin/server", render_file("server")

  # Prevent test noise in generators

  application \
    <<-RB.gsub(/^      /, "")
      config.generators do |g|
            g.test_framework nil
            g.factory_girl false
            g.scaffold_stylesheet false
          end
    RB

  # Configure mailer in development

  environment \
    "config.action_mailer.default_url_options = { host: \"localhost\", port: 3000 }",
    env: "development"

  # Better default favicon

  remove_file "public/favicon.ico"
  file "public/favicon.ico",
    render_file("favicon.ico")

  # Better default README

  remove_file "README.md"
  file "README.md",
    render_file("README.md")

  prepend_file "README.md" do
    <<-MD.gsub(/^      /, "")
      # #{@app_name.titleize}

    MD
  end

  # TODO: Add a prompt about whether to include BS and/or FA
  # TODO: Update for BS4 beta

  # remove_file "app/assets/stylesheets/application.css"
  # file "app/assets/stylesheets/application.scss",
  #   render_file("application.scss")
  #
  # bootstrap_variables_url = "https://raw.githubusercontent.com/twbs/bootstrap-sass/master/templates/project/_bootstrap-variables.sass"
  # file "app/assets/stylesheets/_bootstrap-variables.sass",
  #   open(bootstrap_variables_url).read
  #
  # inside "app" do
  #   inside "assets" do
  #     inside "javascripts" do
  #       insert_into_file "application.js",
  #         after: "//= require rails-ujs\n" do
  #
  #         "//= require jquery\n"
  #         "//= require bootstrap\n"
  #       end
  #     end
  #   end
  # end

  # Remove //= require_tree .

  # gsub_file "app/assets/javascripts/application.js", "//= require_tree .\n", ""

  # Set up dotenv
  file ".env.development", render_file(".env.development")

  append_file ".gitignore" do
    <<-EOF.gsub(/^      /, "")

      # Ignore dotenv files
      /.env*

      whitelist.yml
    EOF
  end

  unless skip_active_admin
    # Set up Active Admin

    generate "active_admin:install"

    gsub_file "db/seeds.rb",
      /AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password')/,
      "AdminUser.create(email: \"admin@example.com\", password: \"password\", password_confirmation: \"password\")"

    rails_command "db:migrate"
    rails_command "db:seed"

    inside "config" do
      inside "initializers" do
        insert_into_file "active_admin.rb",
          after: "ActiveAdmin.setup do |config|\n" do
          <<-RUBY.gsub(/^      /, "")
            # If you are using Devise's before_action :authenticate_user!
            #   in your ApplicationController, then uncomment the following:

            # config.skip_before_action :authenticate_user!

          RUBY
        end

        gsub_file "active_admin.rb",
          "  # config.comments_menu = false\n",
          "  config.comments_menu = false\n"
      end
    end
  end

  # Install annotate

  generate "annotate:install"

  # Set up rspec and capybara

  generate "rspec:install"

  remove_file ".rspec"
  file ".rspec", render_file(".rspec")

  inside "spec" do
    insert_into_file "rails_helper.rb",
      after: "require 'rspec/rails'\n" do
      <<-RUBY.gsub(/^        /, "")
        require "capybara/rails"
        require "capybara/rspec"
      RUBY
    end
  end

  prepend_file "spec/spec_helper.rb" do
    <<-'RUBY'.gsub(/^      /, "")
      require "factory_girl_rails"
      require "#{File.expand_path('../support/json_output_formatter', __FILE__)}"
    RUBY
  end

  file "spec/support/json_output_formatter.rb", render_file("json_output_formatter.rb")

  inside "spec" do
    insert_into_file "spec_helper.rb",
      after: "RSpec.configure do |config|\n" do
      <<-RUBY.gsub(/^      /, "")
        config.include FactoryGirl::Syntax::Methods
        config.example_status_persistence_file_path = "examples.txt"

        def h(hint_identifiers)
          hint_identifiers.split.map { |identifier| I18n.t("hints.\#{identifier}") }
        end
      RUBY
    end
  end

  # Copy hints

  remove_file "config/locales/en.yml"
  file "config/locales/en.yml",
    render_file("en.yml")

  # Add rails spec:update task

  file "lib/tasks/project.rake",
    render_file("project.rake")

  gsub_file "lib/tasks/project.rake",
    /app_name/,
    @app_name

  # Add firstdraft configuration

  file ".grades.yml",
    render_file(".grades.yml")

  # Add bin executable whitelist

  file "bin/whitelist",
    render_file("whitelist")

  # Add whitelist yml

  file "whitelist.yml",
    render_file("whitelist.yml")

  inside "config" do
    inside "environments" do
      insert_into_file "development.rb", :after => "Rails.application.configure do\n" do
        "path = Rails.root.join('whitelist.yml')\n"
        "if File.exist?(path)\n"
          "whitelisted_ips = YAML.load_file(path)\n"
          "config.web_console.whitelisted_ips = whitelisted_ips\n"
        "end"
      end
    end
  end

  # Turn off CSRF protection

  gsub_file "app/controllers/application_controller.rb",
    /protect_from_forgery with: :exception/,
    "# protect_from_forgery with: :exception"

  rails_command "db:migrate"

  run "chmod 775 bin/setup"
  run "chmod 775 bin/whitelist"

  git :init
  git add: "-A"
  git commit: "-m \"rails new\""
end

# TODO List
# =========

# Add a rails engine to provide /console in all apps
# Add a rails engine to provide /git in all apps
# Add a rails engine to provide /rails in all apps

# Create branch for -target
# Create deploy script to push target branch to heroku

# Create/modify bin/setup
# file("setup.sh") do
#   <<-SCRIPT.gsub(/^\s+/, "")
#     #!/bin/bash
#
#     echo "Making sure you have all the gems this app depends upon installed..."
#     bundle install --without production
#
#     echo "Building the database..."
#     rake db:migrate
#
#     echo "Populating the database with dummy data.."
#     rake db:seed
#   SCRIPT
# end
#
# file("setup.bat") do
#   <<-SCRIPT.gsub(/^\s+/, "")
#     echo "Making sure you have all the gems this app depends upon installed..."
#     bundle install --without production
#
#     echo "Building the database..."
#     rake db:migrate
#
#     echo "Populating the database with dummy data.."
#     rake db:seed
#   SCRIPT
# end
