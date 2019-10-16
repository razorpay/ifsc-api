require 'prometheus/client'
require 'prometheus/client/formats/text'

class Metrics
  def initialize
    docstring = 'A counter of successful lookups made against each bank'
    @bank_metrics =
      Prometheus::Client.registry.counter(:bank_lookups,
                                          docstring: docstring,
                                          labels: [:bank])
  end

  def increment(ifsc)
    code = ifsc[0...4]
    @bank_metrics.increment(labels: { bank: code })
  end

  def format
    Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
  end
end
