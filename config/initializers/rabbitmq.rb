connection = Bunny.new(
  host: 'localhost',
  port: 5672,
  user: 'admin',
  password: 'admin123'
)

connection.start

$channel = connection.create_channel