require 'json'
require "redis"

redis = Redis.new

puts "[+] Reading all JSON data"

Dir.glob("data/*.json") do |file|
  bank = File.basename file, ".json"
  if Regexp.new("[A-Z]{4}").match(bank)
    data = JSON.parse File.read file
    data.each do |ifsc, data|
      # Remove the extra keys from the JSON files
      data.delete_if { |key| ['BANK', 'IFSC'].include? key }
      redis.hmset ifsc, *data
    end
  end
end

puts "[+] Dumping data to RDB file"
redis.save