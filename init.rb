require 'json'
require 'redis'
require 'benchmark'
require 'to_slug'
require 'sitemap_generator'

redis = Redis.new

def log(msg)
  puts "[+] (#{Time.now.strftime('%r')}) #{msg}"
end

def add_to_sitemap(sitemap, ifsc, data)
  url = nil
  if data['BANK'] && data['BRANCH']
    url = "/#{data['BANK'].to_s.to_slug}/#{data['BRANCH'].to_s.to_slug}/#{ifsc}"
  end
  if url
    config = { lastmod: Time.now, changefreq: 'monthly', priority: 0.3 }
    sitemap.add url, config
  end
end

Benchmark.bm(18) do |bm|
  bm.report('Ingest:') do
    # CHANGE TO .com before merging
    SitemapGenerator::Sitemap.default_host = 'https://ifsc.stage.razorpay.in'
    SitemapGenerator::Sitemap.create_index = true

    SitemapGenerator::Sitemap.create do |s|
      s.add '/', changefreq: 'daily', priority: 0.9
      Dir.glob('data/*.json') do |file|
        log "Processing #{file}"
        bank = File.basename file, '.json'
        if Regexp.new('[A-Z]{4}').match(bank)
          data = JSON.parse File.read file
          data.each do |ifsc, d|
            begin
              add_to_sitemap(s, ifsc, d)
            rescue Exception => e
              puts e
            end

            # Remove the extra keys from the JSON files
            d.delete_if { |key| %w[BANK IFSC].include? key }
            redis.hmset ifsc, *d
          end
          log "Processed #{data.size} entries"
        end
      end
    end
  end

  bm.report('Dump:') do
    redis.save
  end
end

log('Data saved to Redis')
