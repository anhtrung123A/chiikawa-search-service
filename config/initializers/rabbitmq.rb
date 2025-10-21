connection = Bunny.new(
  host: ENV['RABBITMQ_HOST'] || 'localhost',
  port: ENV['RABBITMQ_PORT'] || 5672,
  user: ENV['RABBITMQ_USER'] || 'admin',
  password: ENV['RABBITMQ_PASSWORD'] || 'admin123'
)

connection.start
$channel = connection.create_channel
