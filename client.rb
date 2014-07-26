require 'socket'
require 'singleton'

$ip_address        = IPSocket.getaddress(Socket.gethostname)
$name              = ENV.fetch("NAME")
$api_url           = ENV.fetch("API_URL")
$websocket_api_url = ENV.fetch("WEBSOCKET_API_URL")

class Service
  include Singleton

  def url(path)
    path.gsub!(%r{^/}, "")
    "#{$api_url}/#{path}"
  end

  def register(ip_address, name)
    response = post("/nodes", ip_address: ip_address, name: name)
    if response.success?
      response.body.to_hash[:access_token]
    end
  end

  def deregister(ip_address)
    delete("/nodes", ip_address: ip_address)
  end

  def post(path, **body)
    # ...
  end

  def delete(path, **params)
    # ...
  end
end

class Command
  def initialize(message:)
    @message = message
  end

  def each(&blk)
    # ...
  end
end

access_token = Service.instance.register($ip_address, $name)

unless access_token
  puts "Could not register with server."
  exit 1
end

uri = URI($websocket_api_url)
uri.query = "access_token=#{URI.encode(access_token)}"

socket = WebsocketClient.connect(url: uri.to_s, json: true)

unless socket.connected?
  puts "Could not connect to websocket server at #{$websocket_api_url}."
  exit 1
end

socket.on_message(type: "command") do |message|
  Command.new(message: message).each do |line|
    socket.write_json line: line
  end
end

socket.on_message(type: "health") do |message|
  socket.write_json message
end

at_exit do
  socket.close
  Service.instance.deregister($ip_address)
end

sleep
