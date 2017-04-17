require "net/http"
require "net/https"

if RUBY_PLATFORM =~ /darwin/

  desc "Grade project on OS X"
  task grade: ["db:migrate"] do # if needed in the future, add => :environment

    # Not quite right: options work, but barely
    options = {}
    OptionParser.new do |opts|
      opts.on("-v", "--verbose", "Show detailed test results") do |v|
        options[:verbose] = v
      end
    end.parse!

    begin
      config_file_name_base = ".firstdraft_project.yml"
      config_file_name = Rails.root.join(config_file_name_base)
      config = YAML.load_file(config_file_name)
      project_token = config["project_token"]
      submission_url = config["submission_url"]
    rescue
      abort("ERROR: Does the file .firstdraft_project.yml exist?")
    end
    if !project_token
      abort("ERROR: Is project_token set in .firstdraft_project.yml?")
    end
    if !submission_url
      abort("ERROR: Is submission_url set in .firstdraft_project.yml?")
    end

    student_token_filename_base = ".firstdraft_student.yml"
    gitignore_filename = Rails.root.join(".gitignore")
    if File.readlines(gitignore_filename).grep(/^\/.firstdraft_student.yml$/).size == 0
      File.open(gitignore_filename, "a+") do |file|
        file.puts "/#{student_token_filename_base}"
      end
    end
    personal_access_token_filename = Rails.root.join(student_token_filename_base)
    if File.file?(personal_access_token_filename)
      student_config = YAML.load_file(personal_access_token_filename)
      personal_access_token = student_config["personal_access_token"]
    else
      student_config = {}
      personal_access_token = nil
    end
    if !personal_access_token
      puts "Enter your access token for this project"
      new_personal_access_token = ""
      while new_personal_access_token == "" do
        print "> "
        new_personal_access_token = $stdin.gets.chomp.strip
        if new_personal_access_token != ""
          personal_access_token = new_personal_access_token
          student_config["personal_access_token"] = personal_access_token
          File.write(personal_access_token_filename, YAML.dump(student_config))
        end
      end
    end

    header_outline_counter = "A"
    puts "* You are running tests and submitting the results."
    puts "* WITH DETAILED RESULTS" if options[:verbose]
    puts "* IGNORING ARGUMENTS #{ARGV[1..-1]}" if ARGV.length > 1

    if options[:verbose]
      puts
      puts "#{header_outline_counter}. READ PERSONAL/PROJECT SETTINGS".header_format
      header_outline_counter = header_outline_counter.next
      puts "- Personal access token: #{personal_access_token} [#{student_token_filename_base}]"
      puts "- Project token: #{project_token} [#{config_file_name_base}]"
      puts "- Submission URL: #{submission_url} [#{config_file_name_base}]"
    end

    puts
    puts "#{header_outline_counter}. RUN TESTS".header_format
    header_outline_counter = header_outline_counter.next
    rspec_output_string_json = `bundle exec rspec --order default --format json`
    rspec_output_json = JSON.parse(rspec_output_string_json)
    puts "- #{rspec_output_json["summary_line"]}".result_format
    puts "- For detailed results: run 'rails grade --verbose' or 'rails grade -v'" if !options[:verbose]

    puts
    puts "#{header_outline_counter}. SUBMIT RESULTS".header_format
    header_outline_counter = header_outline_counter.next
    data = {
      project_token: project_token,
      access_token: personal_access_token,
      test_output: rspec_output_json,
      checksums: {
        tests: checksum_tests,
        student_code: checksum_student_code,
        student_code_details: {
          app_assets: run_checksum(Rails.root.join("app/assets"), is_folder),
          app_controllers: run_checksum(Rails.root.join("app/controllers"), is_folder),
          app_models: run_checksum(Rails.root.join("app/models"), is_folder),
          app_views: run_checksum(Rails.root.join("app/views"), is_folder),
          db: run_checksum(Rails.root.join("db"), is_folder),
          config_routes: run_checksum(Rails.root.join("config", "routes.rb"), is_file),
          gemfile: run_checksum(Rails.root.join("Gemfile"), is_file),
          public: run_checksum(Rails.root.join("public"), is_folder)
        }
      }
    }

    uri = URI(submission_url)
    begin
      use_ssl = uri.scheme == "https" ? true : false
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = data.to_json
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
        http.request(req)
      end
    rescue Exception => e
      # see http://stackoverflow.com/questions/5370697/what-s-the-best-way-to-handle-exceptions-from-nethttp
      network_error_msg_base = "NETWORK ERROR: the submission to #{submission_url} didn't work.  Possible causes: (a) your internet connection or (b) the grading server.  For (b), try submitting again, and if that doesn't work, try again after some time -- and if that still doesn't work, let your instructor know :)"
      if options[:verbose]
        abort("#{network_error_msg_base}  \n\nTechnical error message that may or may not be helpful: #{e.inspect}\n".error_format)
      else
        abort("#{network_error_msg_base}  For a technical error message that may or may not be helpful, run 'rails grade --verbose' or 'rails grade -v'.\n".error_format)
      end
    end
    if res.kind_of? Net::HTTPCreated
      results_url = JSON.parse(res.body)["url"]
      puts "- Done! Results URL: ".result_format + "#{results_url}".link_format.result_format
      puts
      if options[:verbose]
        puts "#{header_outline_counter}. DETAILED TEST RESULTS".header_format
        header_outline_counter = header_outline_counter.next
        rspec_output_string_doc = `bundle exec rspec --order default --format documentation --color --tty` # "--require spec_helper"?
        puts rspec_output_string_doc
      else
        `open #{results_url}`
      end
    elsif res.kind_of? Net::HTTPUnprocessableEntity
      puts "- ERROR: #{res.body}".error_format
      puts
    # elsif res.kind_of? Net::HTTPInternalServerError
    else
      puts "- ERROR: #{res.inspect}, #{res.body}".error_format
      puts
    end

  end

  def checksum_tests
    md5 = Digest::MD5.new
    Dir["#{Rails.root.join("spec")}/**/*"]
      .reject{ |f| File.directory?(f) }
      .each { |f| md5 << File.read(f) }
    md5 << File.read(Rails.root.join("lib", "tasks", "grade.rake"))
    md5 << File.read(Rails.root.join(".firstdraft_project.yml"))
    return md5.hexdigest
  end

  def checksum_student_code
    md5 = Digest::MD5.new
    Dir["#{Rails.root.join("app")}/**/*"]
      .reject{ |f| File.directory?(f) }
      .each { |f| md5 << File.read(f) }
    Dir["#{Rails.root.join("public")}/**/*"]
      .reject{ |f| File.directory?(f) }
      .each { |f| md5 << File.read(f) }
    Dir["#{Rails.root.join("db")}/**/*"]
      .reject{ |f| File.directory?(f) }
      .each { |f| md5 << File.read(f) }
    md5 << File.read(Rails.root.join("config", "routes.rb"))
    md5 << File.read(Rails.root.join("Gemfile"))
    return md5.hexdigest
  end

  def is_folder;  return true     end
  def is_file;    return false    end
  def run_checksum(f_path, f_is_folder)
    md5 = Digest::MD5.new
    if(f_is_folder)
      Dir["#{f_path}/**/*"]
        .reject{ |f| File.directory?(f) }
        .each { |f| md5 << File.read(f) }
    else
      md5 << File.read(f_path)
    end
    return md5.hexdigest
  end

  # Taken from: http://stackoverflow.com/questions/1489183/colorized-ruby-output
  class String
    def black;          "\e[30m#{self}\e[0m"      end
    def red;            "\e[31m#{self}\e[0m"      end
    def green;          "\e[32m#{self}\e[0m"      end
    def brown;          "\e[33m#{self}\e[0m"      end
    def blue;           "\e[34m#{self}\e[0m"      end
    def magenta;        "\e[35m#{self}\e[0m"      end
    def cyan;           "\e[36m#{self}\e[0m"      end
    def gray;           "\e[37m#{self}\e[0m"      end

    def bg_black;       "\e[40m#{self}\e[0m"      end
    def bg_red;         "\e[41m#{self}\e[0m"      end
    def bg_green;       "\e[42m#{self}\e[0m"      end
    def bg_brown;       "\e[43m#{self}\e[0m"      end
    def bg_blue;        "\e[44m#{self}\e[0m"      end
    def bg_magenta;     "\e[45m#{self}\e[0m"      end
    def bg_cyan;        "\e[46m#{self}\e[0m"      end
    def bg_gray;        "\e[47m#{self}\e[0m"      end

    def bold;           "\e[1m#{self}\e[22m"      end
    def italic;         "\e[3m#{self}\e[23m"      end
    def underline;      "\e[4m#{self}\e[24m"      end
    def blink;          "\e[5m#{self}\e[25m"      end
    def reverse_color;  "\e[7m#{self}\e[27m"      end

    def no_colors;      self.gsub /\e\[\d+m/, ""  end

    # Specific formatting for 'rails grade'
    def header_format;  self.underline            end
    def result_format;  self.bold                 end
    def link_format;    self                      end
    def error_format;   self.bg_red.bold          end
  end

else

  desc "Grade project on Windows"
  task :grade do # if needed in the future, add => :environment

    # Windows prep
    `rake db:migrate RAILS_ENV=test`

    # Not quite right: options work, but barely
    options = {}
    OptionParser.new do |opts|
      opts.on("-v", "--verbose", "Show detailed test results") do |v|
        options[:verbose] = v
      end
    end.parse!

    begin
      config_file_name_base = ".firstdraft_project.yml"
      config_file_name = Rails.root.join(config_file_name_base)
      config = YAML.load_file(config_file_name)
      project_token = config["project_token"]
      submission_url = config["submission_url"]
    rescue
      abort("ERROR: Does the file .firstdraft_project.yml exist?")
    end
    if !project_token
      abort("ERROR: Is project_token set in .firstdraft_project.yml?")
    end
    if !submission_url
      abort("ERROR: Is submission_url set in .firstdraft_project.yml?")
    end

    student_token_filename_base = ".firstdraft_student.yml"
    gitignore_filename = Rails.root.join(".gitignore")
    if File.readlines(gitignore_filename).grep(/^\/.firstdraft_student.yml$/).size == 0
      File.open(gitignore_filename, "a+") do |file|
        file.puts "/#{student_token_filename_base}"
      end
    end
    personal_access_token_filename = Rails.root.join(student_token_filename_base)
    if File.file?(personal_access_token_filename)
      student_config = YAML.load_file(personal_access_token_filename)
      personal_access_token = student_config["personal_access_token"]
    else
      student_config = {}
      personal_access_token = nil
    end
    if !personal_access_token
      puts "Enter your access token for this project"
      new_personal_access_token = ""
      while new_personal_access_token == "" do
        print "> "
        new_personal_access_token = $stdin.gets.chomp.strip
        if new_personal_access_token != ""
          personal_access_token = new_personal_access_token
          student_config["personal_access_token"] = personal_access_token
          File.write(personal_access_token_filename, YAML.dump(student_config))
        end
      end
    end

    header_outline_counter = "A"
    puts "* You are running tests and submitting the results."
    puts "* WITH DETAILED RESULTS" if options[:verbose]
    puts "* IGNORING ARGUMENTS #{ARGV[1..-1]}" if ARGV.length > 1

    if options[:verbose]
      puts
      puts "#{header_outline_counter}. READ PERSONAL/PROJECT SETTINGS"#.header_format
      header_outline_counter = header_outline_counter.next
      puts "- Personal access token: #{personal_access_token} [#{student_token_filename_base}]"
      puts "- Project token: #{project_token} [#{config_file_name_base}]"
      puts "- Submission URL: #{submission_url} [#{config_file_name_base}]"
    end

    puts
    puts "#{header_outline_counter}. RUN TESTS"#.header_format
    header_outline_counter = header_outline_counter.next
    rspec_output_string_json = `bundle exec rspec --order default --format json`
    rspec_output_json = JSON.parse(rspec_output_string_json)
    puts "- #{rspec_output_json["summary_line"]}"#.result_format
    puts "- For detailed results: run 'rails grade --verbose' or 'rails grade -v'" if !options[:verbose]

    puts
    puts "#{header_outline_counter}. SUBMIT RESULTS"#.header_format
    header_outline_counter = header_outline_counter.next
    data = {
      project_token: project_token,
      access_token: personal_access_token,
      test_output: rspec_output_json,
      checksums: {
        tests: checksum_tests,
        student_code: checksum_student_code,
        student_code_details: {
          app_assets: run_checksum(Rails.root.join("app/assets"), is_folder),
          app_controllers: run_checksum(Rails.root.join("app/controllers"), is_folder),
          app_models: run_checksum(Rails.root.join("app/models"), is_folder),
          app_views: run_checksum(Rails.root.join("app/views"), is_folder),
          db: run_checksum(Rails.root.join("db"), is_folder),
          config_routes: run_checksum(Rails.root.join("config", "routes.rb"), is_file),
          gemfile: run_checksum(Rails.root.join("Gemfile"), is_file),
          public: run_checksum(Rails.root.join("public"), is_folder)
        }
      }
    }

    # TEMPORARY Windows fixes
    # 1. SSL issues leading to submissions errors
    # 2. Fix 1: do not use SSL for now when communicating with grades.firstdraft.com
    # 3. Fix 2 (minor): do not open results URL automatically (command used does not work in Windows shell)
    # 4. Fix 3 (minor): no formatting (as written, does not work reliably in Windows)

    # TEMP Windows fix
    submission_url = submission_url.sub("https", "http")

    uri = URI(submission_url)
    begin
      use_ssl = uri.scheme == "https" ? true : false
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = data.to_json
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
        http.request(req)
      end
    rescue Exception => e
      # see http://stackoverflow.com/questions/5370697/what-s-the-best-way-to-handle-exceptions-from-nethttp
      network_error_msg_base = "NETWORK ERROR: the submission to #{submission_url} didn't work.  Possible causes: (a) your internet connection or (b) the grading server.  For (b), try submitting again, and if that doesn't work, try again after some time -- and if that still doesn't work, let your instructor know :)"
      if options[:verbose]
        abort("#{network_error_msg_base}  \n\nTechnical error message that may or may not be helpful: #{e.inspect}\n") #.error_format
      else
        abort("#{network_error_msg_base}  For a technical error message that may or may not be helpful, run 'rails grade --verbose' or 'rails grade -v'.\n") #.error_format
      end
    end
    if res.kind_of? Net::HTTPCreated
      results_url = JSON.parse(res.body)["url"]
      puts "- Done! Results URL: " + "#{results_url}" # puts "- Done! Results URL: ".result_format + "#{results_url}".link_format.result_format
      puts
      if options[:verbose]
        puts "#{header_outline_counter}. DETAILED TEST RESULTS"#.header_format
        header_outline_counter = header_outline_counter.next
        rspec_output_string_doc = `bundle exec rspec --order default --format documentation --color --tty` # "--require spec_helper"?
        puts rspec_output_string_doc
      else
        `cmd /c start #{results_url}`
      end
    elsif res.kind_of? Net::HTTPUnprocessableEntity
      puts "- ERROR: #{res.body}"#.error_format
      puts
      # elsif res.kind_of? Net::HTTPInternalServerError
    else
      puts "- ERROR: #{res.inspect}, #{res.body}"#.error_format
      puts
    end

  end

  def checksum_tests
    md5 = Digest::MD5.new
    Dir["#{Rails.root.join("spec")}/**/*"]
    .reject{ |f| File.directory?(f) }
    .each { |f| md5 << File.read(f) }
    md5 << File.read(Rails.root.join("lib", "tasks", "grade.rake"))
    md5 << File.read(Rails.root.join(".firstdraft_project.yml"))
    return md5.hexdigest
  end

  def checksum_student_code
    md5 = Digest::MD5.new
    Dir["#{Rails.root.join("app")}/**/*"]
    .reject{ |f| File.directory?(f) }
    .each { |f| md5 << File.read(f) }
    Dir["#{Rails.root.join("public")}/**/*"]
    .reject{ |f| File.directory?(f) }
    .each { |f| md5 << File.read(f) }
    Dir["#{Rails.root.join("db")}/**/*"]
    .reject{ |f| File.directory?(f) }
    .each { |f| md5 << File.read(f) }
    md5 << File.read(Rails.root.join("config", "routes.rb"))
    md5 << File.read(Rails.root.join("Gemfile"))
    return md5.hexdigest
  end

  def is_folder;  return true     end
  def is_file;    return false    end
  def run_checksum(f_path, f_is_folder)
    md5 = Digest::MD5.new
    if(f_is_folder)
      Dir["#{f_path}/**/*"]
      .reject{ |f| File.directory?(f) }
      .each { |f| md5 << File.read(f) }
    else
      md5 << File.read(f_path)
    end
    return md5.hexdigest
  end

  # # Taken from: http://stackoverflow.com/questions/1489183/colorized-ruby-output
  # class String
  #   def black;          "\e[30m#{self}\e[0m"      end
  #   def red;            "\e[31m#{self}\e[0m"      end
  #   def green;          "\e[32m#{self}\e[0m"      end
  #   def brown;          "\e[33m#{self}\e[0m"      end
  #   def blue;           "\e[34m#{self}\e[0m"      end
  #   def magenta;        "\e[35m#{self}\e[0m"      end
  #   def cyan;           "\e[36m#{self}\e[0m"      end
  #   def gray;           "\e[37m#{self}\e[0m"      end

  #   def bg_black;       "\e[40m#{self}\e[0m"      end
  #   def bg_red;         "\e[41m#{self}\e[0m"      end
  #   def bg_green;       "\e[42m#{self}\e[0m"      end
  #   def bg_brown;       "\e[43m#{self}\e[0m"      end
  #   def bg_blue;        "\e[44m#{self}\e[0m"      end
  #   def bg_magenta;     "\e[45m#{self}\e[0m"      end
  #   def bg_cyan;        "\e[46m#{self}\e[0m"      end
  #   def bg_gray;        "\e[47m#{self}\e[0m"      end

  #   def bold;           "\e[1m#{self}\e[22m"      end
  #   def italic;         "\e[3m#{self}\e[23m"      end
  #   def underline;      "\e[4m#{self}\e[24m"      end
  #   def blink;          "\e[5m#{self}\e[25m"      end
  #   def reverse_color;  "\e[7m#{self}\e[27m"      end

  #   def no_colors;      self.gsub /\e\[\d+m/, ""  end

  #   # Specific formatting for 'rails grade'
  #   def header_format;  self.underline            end
  #   def result_format;  self.bold                 end
  #   def link_format;    self                      end
  #   def error_format;   self.bg_red.bold          end
  # end
end
