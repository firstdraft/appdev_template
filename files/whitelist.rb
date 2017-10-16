path = Rails.root.join('whitelist.yml')
if File.exist?(path)
  whitelisted_ips = YAML.load_file(path)
  whitelisted_ips.each do |ip|
    BetterErrors::Middleware.allow_ip!(ip)
  end
end
