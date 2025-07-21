# frozen_string_literal: true

# ** THE FIX **: This line loads the Bundler environment directly within the script.
# It finds the Gemfile and makes all the gems available to this Ruby process.
# This makes `bundle exec` unnecessary and bypasses the shell environment issues.
require 'bundler/setup'

require 'json'
require 'redis'
require 'benchmark'

# This connects to Redis on localhost:6379, which is the correct
# address for the self-contained builder stage.
redis = Redis.new

def log(msg)
  puts "[+] (#{Time.now.strftime('%r')}) #{msg}"
end

Benchmark.bm(18) do |bm|
  bm.report('Ingest:') do
    Dir.glob('data/*.json') do |file|
      log "Processing #{file}"
      bank = File.basename file, '.json'
      if Regexp.new('[A-Z]{4}').match(bank)
        data = JSON.parse File.read file
        data.each do |ifsc, d|
          # Remove the extra keys from the JSON files
          d.delete_if { |key| %w[BANK IFSC].include? key }
          redis.hmset ifsc, *d
        end
        log "Processed #{data.size} entries"
      end
    end
  end
  bm.report('Dump:') do
    # This command saves the in-memory data to the dump.rdb file.
    redis.save
  end
end
log('Data saved to Redis')
