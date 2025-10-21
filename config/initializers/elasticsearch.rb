ELASTICSEARCH_CLIENT = Elasticsearch::Client.new(
  hosts: [
    {
      host: ENV['ELASTICSEARCH_HOST'] || 'localhost',
      port: (ENV['ELASTICSEARCH_PORT'] || 9200).to_i,
      scheme: 'http',
    }
  ],
  log: true
)
