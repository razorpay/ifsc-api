require 'prometheus/client'
require 'prometheus/client/formats/text'

class Metrics
  def initialize
    @bank_metrics = Prometheus::Client.registry.counter(:bank_lookups, docstring: 'A counter of successful lookups made against each bank')
  end

  def increment(ifsc)
    code = ifsc[0...4]
    @bank_metrics.increment({"bank" => code})
  end

  def format
    Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
  end
end
