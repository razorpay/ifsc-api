require 'json'
require 'redis'
require 'yaml'

redis = Redis.new

puts "[+] Reading all JSON data"

Dir.glob("data/*.json") do |file|
  bank = File.basename file, ".json"
  # Only add 4-character filenames to redis
  if Regexp.new("[A-Z]{4}").match(bank)
    data = JSON.parse File.read file
    data.each do |ifsc, data|
      # Remove the extra keys from the JSON files
      data.delete_if { |key| ['BANK', 'IFSC'].include? key }
      redis.hmset ifsc, *data
    end
    puts "[+] Deleting #{file}"
    File.delete file
  end
end

puts "[+] Storing redirects"
redirects = YAML.load_file('data/redirects.yml')
redis.hmset 'redirects', *redirects
puts "[+] Deleting redirects file"
File.delete 'data/redirects.yml'

puts "[+] Dumping data to RDB file"
redis.save