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
      file = File.join(File.expand_path(File.dirname(__FILE__)), "files", filename)
      open(file).read
    end
  else
    IO.read(path_to_file(filename))
  end
end

skip_active_admin = true
skip_devise = true
# skip_devise = yes?("Skip Devise?")

# Remove default sqlite3 version
# =================
gsub_file "Gemfile", /^gem\s+["']sqlite3["'].*$/,''
gsub_file "Gemfile", /^gem\s+["']sass-rails["'].*$/,""

# Add standard gems
# =================
gem "rack-timeout", require: "rack/timeout/base"
gem 'sprockets', '< 4'
gem 'sassc-rails'
# Javascript for Gitpod
gem 'execjs'
gem 'therubyracer', :platforms => :ruby

gem_group :development, :test do
  gem "amazing_print"
  # gem "console_ip_whitelist", github: "firstdraft/console_ip_whitelist"
  gem "dotenv-rails"
  gem "grade_runner", github: "firstdraft/grade_runner"
  gem "pry-rails"
  gem "sqlite3", "~> 1.4.1"
  gem "table_print"
  gem "web_git", github: "firstdraft/web_git", branch: "spring2020"
end

gem_group :development do
  gem "annotate"
  gem "better_errors", "2.6"
  gem "binding_of_caller"
  gem "draft_generators", github: "firstdraft/draft_generators", branch: "winter-2020"
  # gem "letter_opener"
  # gem "meta_request"
  gem "rails_db", "2.3.1"
end

gem_group :test do
  gem "capybara"
  gem "factory_bot_rails"
  gem "rspec-rails"
  gem "webmock"
  gem "rspec-html-matchers"
  gem "selenium-webdriver"
end

gem_group :production do
  gem "pg"
end

gsub_file "Gemfile",
  /#\sgem [',"]bcrypt[',"].*/,
  "gem 'bcrypt'"

gem "devise" unless skip_devise
# gem "activeadmin", "2.2.0"
# gem "bootstrap-sass"
# gem "jquery-rails"
# gem "font-awesome-sass", "~> 4.7.0"

# Use WEBrick

gsub_file "Gemfile",
  /gem 'jbuilder'.*$/,
  ""
gsub_file "Gemfile",
  "# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder",
  ""

gsub_file "Gemfile",
    /gem 'tzinfo-data'.*$/,
    ""

after_bundle do
  # Overwrite bin/setup

  remove_file "bin/setup"
  file "bin/setup", render_file("setup")

  # Add dev:prime task

  file "lib/tasks/dev.rake", render_file("dev.rake")

  # Add bin/server

  file "bin/server", render_file("server")

  # Prevent test noise in generators

  load_defaults = open("config/application.rb").read.to_s.match(/config.load_defaults \d.\d\n/)

  inside "config" do
    insert_into_file "application.rb",
      after: load_defaults[0] do
      <<-RUBY.gsub(/^      /, "")
          config.generators do |g|
            g.test_framework nil
            g.factory_bot false
            g.scaffold_stylesheet false
            g.stylesheets     false
            g.javascripts     false
            g.helper          false
          end
          
          config.action_controller.default_protect_from_forgery = false
          config.active_record.belongs_to_required_by_default = false
          RUBY
      end
  end

  gsub_file "config/application.rb",
          /require "active_job\/railtie"$/,
          "# require \"active_job\/railtie\""

  # environment \
  #   "config.action_mailer.default_url_options = { host: \"localhost\", port: 3000 }",
  #   env: "development"

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


  inside "config" do
    inside "environments" do
      insert_into_file "development.rb", after: "Rails.application.configure do\n" do
        <<-RB.gsub(/^      /, "")
          config.hosts.clear
          path = Rails.root.join("whitelist.yml")
          default_whitelist_path = Rails.root.join("default_whitelist.yml")
          whitelisted_ips = []

          if File.exist?(path)
            whitelisted_ips = YAML.load_file(path)
          end

          if File.exist?(default_whitelist_path)
            whitelisted_ips = whitelisted_ips.concat(YAML.load_file(default_whitelist_path))
          end

          config.web_console.permissions = whitelisted_ips
          config.web_console.whiny_requests = false

          BetterErrors::Middleware.allow_ip! '10.138.0.0/16'

        RB
      end
    end
  end

  gsub_file "config/environments/development.rb",
    "config.assets.debug = true",
    "config.assets.debug = false"

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
  inside "app" do
    inside "views" do
      inside "layouts" do
        insert_into_file "application.html.erb",
          after: "    <%= csrf_meta_tags %>\n" do
            <<-HTML.gsub(/^        /, "")

            <!-- Expand the number of characters we can use in the document beyond basic ASCII 🎉 -->
            <meta charset="utf-8">

            <!-- Make it responsive to small screens -->
            <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
          HTML
        end
      end
    end
  end

  # empty_directory File.join("app", "views", "application")
  
  empty_directory File.join("config", "initializers", "active_record")
  empty_directory File.join("config", "initializers", "active_record", "relation")
  
  # Remove require_tree .

  gsub_file "app/assets/stylesheets/application.css", " *= require_tree .\n", ""
  gsub_file "app/views/layouts/application.html.erb", "javascript_pack_tag", "javascript_include_tag"

  # Better backtraces
  file "config/initializers/nicer_errors.rb", render_file("nicer_errors.rb")
  file "config/initializers/rails_db.rb", render_file("rails_db.rb")
  
  file "config/initializers/active_record/relation/delegation_patch.rb", render_file("delegation_patch.rb")
  file "config/initializers/active_record/relation/calculations_patch.rb", render_file("calculations_patch.rb")
  file "config/initializers/active_record/attribute_methods_patch.rb", render_file("attribute_methods_patch.rb")
  file "config/initializers/active_record/relation_patch.rb", render_file("relation_patch.rb")

  file "config/initializers/fetch_store_patch.rb", render_file("fetch_store_patch.rb")
  remove_file "config/puma.rb"
  file "config/puma.rb", render_file("puma.rb")

  file ".gitpod.yml", render_file(".gitpod.yml")
  file ".pryrc", render_file(".pryrc")
  file "Procfile", render_file("Procfile")

  inside "config" do
    inside "initializers" do
      append_file "backtrace_silencers.rb" do
        <<-RUBY.gsub(/^          /, "")

          Rails.backtrace_cleaner.add_silencer { |line| line =~ /lib|gems/ }

        RUBY
      end
    end
  end

  inside "app" do
    inside "assets" do
      inside "config" do
        append_file "manifest.js" do
          <<-RUBY.gsub(/^          /, "")
          //= link_directory ../javascripts .js

          RUBY
        end
      end
    end
  end

  create_file "app/assets/javascripts/application.js"
  
  inside "app" do
    inside "assets" do
      inside "javascripts" do
        append_file "application.js" do
          <<-RUBY.gsub(/^          /, "")
          /*
          *= require_self
          */
          RUBY
        end
      end
    end
  end

  initializer 'open_uri.rb', <<-CODE
    require("open-uri")

  CODE

  # Set up dotenv
  file ".env.development", render_file(".env.development")

  append_file ".gitignore" do
    <<-EOF.gsub(/^      /, "")

      # Ignore dotenv files
      /.env*

      .rbenv-gemsets
      examples.txt
      whitelist.yml
      grades.yml
      cloud9_plugins.sh
      appdev/
      node_modules
      package-lock.json
      core.chrome*
      !vendor/
    EOF
  end

  gsub_file ".gitignore",
  "/db/*.sqlite3\n/db/*.sqlite3-journal",
  "# /db/*.sqlite3\n# /db/*.sqlite3-journal"

  unless skip_active_admin
    # Set up Active Admin

    generate "active_admin:install"

    gsub_file "db/seeds.rb",
      /AdminUser.create!.*/,
      <<~RUBY
        if Rails.env.development?
          AdminUser.create({
            :email => "admin@example.com",
            :password => "password",
            :password_confirmation => "password",
          })
        end
      RUBY

    rails_command "db:migrate"
    rails_command "db:seed"

    empty_directory "vendor/app"
    empty_directory "vendor/app/models"

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

        gsub_file "active_admin.rb",
          "  # config.comments_registration_name = 'AdminComment'\n",
          "  config.comments_registration_name = 'AdminComment'\n"

         gsub_file "wrap_parameters.rb",
           /# A.+\D*/,
           <<~RUBY
           ActiveSupport.on_load(:active_record) do
             self.include_root_in_json = true
           end
           RUBY
      end
    end
    run "mv app/models/admin_user.rb vendor/app/models"
  end
  
  empty_directory ".theia"
  file ".theia/settings.json", render_file("settings.json")

  generate "web_git:install"
  # Install annotate
  generate "annotate:install"

  # Set up rspec and capybara

  generate "rspec:install"


  remove_file ".rspec"
  file ".rspec", render_file(".rspec")

  empty_directory File.join("spec", "features")
  file "spec/features/dummy_spec.rb", render_file("dummy_spec.rb")

  inside "spec" do
    insert_into_file "rails_helper.rb",
      after: "require 'rspec/rails'\n" do
      <<-RUBY.gsub(/^        /, "")
        require "capybara/rails"
        require "capybara/rspec"
      RUBY
    end
  end

  inside "spec" do
    insert_into_file "rails_helper.rb",
      after: "config.use_transactional_fixtures = true\n" do
      <<-RUBY.gsub(/^        /, "")
          Capybara.register_driver :chrome do |app|
            Capybara::Selenium::Driver.new(app, browser: :chrome)
          end
          
          Capybara.register_driver :headless_chrome do |app|
            capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
            chromeOptions: { args: %w(headless disable-gpu no-sandbox disable-dev-shm-usage) }
          )
          
          Capybara::Selenium::Driver.new app,
            browser: :chrome,
            desired_capabilities: capabilities
          end
          
          Capybara.default_max_wait_time = 3

          Capybara.javascript_driver = :headless_chrome
      RUBY
    end
  end

  # Remove concerns folders
  remove_dir "app/controllers/concerns"
  remove_dir "app/models/concerns"
  remove_dir "app/jobs"

  prepend_file "spec/spec_helper.rb" do
    <<-'RUBY'.gsub(/^      /, "")
      require "factory_bot_rails"
      require "rspec-html-matchers"
      require "#{File.expand_path('../support/json_output_formatter', __FILE__)}"
      require "#{File.expand_path('../support/hint_formatter', __FILE__)}"
    RUBY
  end

  file "spec/support/json_output_formatter.rb", render_file("json_output_formatter.rb")
  file "spec/support/hint_formatter.rb", render_file("hint_formatter.rb")

  inside "spec" do
    insert_into_file "spec_helper.rb",
      after: "RSpec.configure do |config|\n" do
      <<-RUBY.gsub(/^      /, "")
        config.include FactoryBot::Syntax::Methods
        config.include RSpecHtmlMatchers
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

  remove_file "lib/tasks/grade.rake"

  # Add firstdraft configuration

  remove_file ".firstdraft_project.yml"

  file "grades.yml",
    render_file("grades.yml")

  # Add bin executable whitelist

  file "bin/whitelist",
    render_file("whitelist")

  # Add whitelist yml

  file "default_whitelist.yml",
    render_file("default_whitelist.yml")
  
  # Add Dockerfile
  file "Dockerfile", render_file("Dockerfile")

  ruby_version = open(".ruby-version").read
  ruby_version = ruby_version.gsub("ruby-", "").strip
  gsub_file("Dockerfile", "2.6.5", ruby_version)

  rails_command "db:migrate"

  run "chmod 775 bin/server"
  run "chmod 775 bin/setup"
  run "chmod 775 bin/whitelist"

  git :init
  git add: "-A"
  git commit: "-m \"rails new\""
end


# TODO List
# =========

# Ensure inherited resources is not being used by generators

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
