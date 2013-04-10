Building a network service and client with Stark
================================================

Writing a service with Stark isn't hard. Wiring up the Thrift network stuff is
a little challenging, but knowing where to start helps.

Running the examples
--------------------

From the root of the stark repo:

1. `$ ruby -Ilib -Iexamples examples/server.rb &`
1. `$ ruby -Ilib -Iexamples examples/client.rb`

Write the Thrift IDL
--------------------

The first thing you need to do is write a definition for your Thrift service.
Here are some good examples:

* `examples/health.thrift`: a simple service with one procedure and one struct
* `test/profile.thrift`: a more sophisticated service for user profiles
* `test/ThriftSpec.thrift`: everything in Thrift, presented concisely 

An example Thrift service
-------------------------

For the following examples, we'll use this service defintion:

```thrift
struct Healthcheck {
  1: bool ok,
  2: string message
}

service Health {
  Healthcheck check()
}
```

This defines a service with one message, `check` that returns a `Healthcheck`
struct.

Write a client
--------------

Using Stark, you can avoid the need to generate and track sources generated
from your Thrift IDL. A simple Thrift client looks like this:

```ruby
require 'thrift'
require 'stark'

Stark.materialize "examples/health.thrift"

socket    = Thrift::UNIXSocket.new('/tmp/health_sock').tap { |s| s.open }
transport = Thrift::IOStreamTransport.new socket.to_io, socket.to_io
proto     = Thrift::BinaryProtocol.new transport
client    = Health::Client.new proto, proto

result = client.check
```

For your own purposes, you'll probably use a different kind of socket (one of
the TCP-based ones) and your client class will be different. You probably won't need to tinker with the transport and protocol until you've got services in
production.

Write a service
---------------

A Thrift service using Stark has a lot of symmetry to the client. A simple
service looks like this:

```ruby
require 'thrift'
require 'stark'

Stark.materialize "examples/health.thrift"

class Health::Handler

  def check
    Healthcheck.new('ok' => true, "message" => "OK")
  end

end

transport = Thrift::UNIXServerSocket.new '/tmp/health_sock'
processor = Health::Processor.new Health::Handler.new
server    = Thrift::SimpleServer.new processor, transport
server.serve
```

There are a few more moving parts here. We start off similar, requiring `stark`
and `thrift`, then dynamically creating the Ruby classes for our service via
`Stark.materialize`. Next we define a handler class that implements the logic
of our service. It defines the `check` method from our service. We then create
a transport and processor for our service and hook it up to a server class
provided by the `thrift` gem. Calling `serve` starts the server loop.

Not too hard!

Where to go next?
-----------------

* Read up on [Thrift concepts](http://thrift.apache.org/docs/concepts/), it
  will come in handy as you implement your own services and clients.
* Try writing your own service.
* Lots of people are already implementing HTTP services. Luckily, stark can
  help you make the transition from HTTP-based services. You can use
  [stark-http](https://github.com/evanphx/stark-http) to write Thrift clients
  over HTTP and [stark-rack](https://github.com/evanphx/stark-rack) to
  implement Thrift services over HTTP.

