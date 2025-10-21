def wait_for_service(host, port, retries: 10, delay: 3)
  attempts = 0
  begin
    TCPSocket.new(host, port).close
    puts "#{host}:#{port} is ready"
  rescue Errno::ECONNREFUSED
    attempts += 1
    if attempts < retries
      puts "Waiting for #{host}:#{port}... attempt #{attempts}"
      sleep delay
      retry
    else
      raise "Cannot connect to #{host}:#{port} after #{retries} attempts"
    end
  end
end

wait_for_service(ENV['ELASTICSEARCH_HOST'] || 'localhost', 9200, retries: 15, delay: 2)
wait_for_service(ENV['RABBITMQ_HOST'] || 'localhost', 5672, retries: 15, delay: 2)
