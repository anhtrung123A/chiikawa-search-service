class ProductConsumer
  def self.start
    exchange = $channel.fanout('product.events')
    queue = $channel.queue('', durable: true)
    queue.bind(exchange)

    puts "ProductConsumer is waiting for messages..."

    queue.subscribe(block: true) do |_delivery_info, _properties, body|
      begin
        data = JSON.parse(body)
        case data['event']
        when 'created', 'updated'
          ElasticsearchService.index(build_product_payload(data))
        when 'deleted'
          ElasticsearchService.delete(data["id"])
        end
      rescue => e
        puts "Error processing message: #{e.message}"
      end
    end
  end

  private

  def self.build_product_payload(data)
    {
      id: data["id"],
      name: data["name"],
      created_at: data["created_at"],
      categories: data["categories"],
      characters: data["characters"],
      images: data["images"],
      price: data["price"],
      status: data["status"]
    }
  end
end