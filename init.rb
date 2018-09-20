require 'json'
require 'redis'
require 'benchmark'

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
    redis.save
  end
end
log('Data saved to Redis')
