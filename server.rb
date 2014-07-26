require "sinatra"
require "json"

helpers do
  def json(thing)
    content_type :json
    body JSON.generate(thing)
  end

  def json_error(thing)
    json({ type: "error" }.merge(thing))
  end

  def required_params(*param_names)
    status 400
    json_error required: { params: params_names }
  end

  def not_found
    status 404
    json_error message: "not found"
  end

  def server_error
    status 500
    json_error message: "internal server error"
  end

  def with_params(*param_names)
    info = param_names.each_with_object({}) do |name, h|
      if !params.key?(name) || params[name].nil?
        return required_params(*param_names)
      end

      value = params[name]
      h[name] = value
    end

    yield(info)
  end

  def with_node(id)
    node = Node.find info[:node_id]

    return not_found unless node

    yield(node)
  end

  def with_command_and_node
    with_params(:command, :node_id) do |info|
      with_node(info[:node_id]) do |node|
        yield(info[:command], node)
      end
    end
  end
end

get "/" do
  erb :index
end

get "/api/nodes" do
  @nodes = Node.all
  json @nodes.map(&NodeRep)
end

post "/api/nodes/:node_id/commands" do
  with_command_and_node do |command, node|
    content_type :text
    status 200

    stream do |out|
      out << JSON.generate(streaming: true)
      StreamingCommand.new(node: node, command: command).each do |line|
        out << JSON.generate(line: line)
      end
      out << JSON.generate(finished: true)
    end
  end
end

post "/api/nodes" do
  with_params(:name, :ip_address) do |info|
    node = Node.create(info)

    if node
      json access_token: node.access_token
    else
      server_error
    end
  end
end

__END__

@@layout

<!doctype html>
<html>
  <head>
    <title>Remote Control</title>
  </head>
  <body>
    <%= yield %>
  </body>
</html>

@@index

<h1>Hello</h1>
