class ProductConsumer
  def self.start
    exchange = $channel.fanout('product.events')
    queue = $channel.queue('', durable: true)
    queue.bind(exchange)

    puts ("ProductConsumer is waiting for messages...")

    queue.subscribe(block: true) do |_delivery_info, _properties, body|
      data = JSON.parse(body)
      puts ("Received message: #{data.inspect}")

      case data['event']
      when 'created'
        product = {
          id: data["id"],
          name: data["name"],
          created_at: data["created_at"],
          categories: data["categories"],
          characters: data["characters"],
          images: data["images"],
          price: data["price"],
          status: data["status"],
      }
        ElasticsearchService.index(product)
      when 'updated'
        puts ("Received message: #{data.inspect}")
      when 'deleted'
        puts ("Received message: #{data.inspect}")
      end
    end
  end
end