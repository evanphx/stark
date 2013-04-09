Building a network service and client with Stark
------------------------------------------------

Writing a service with Stark isn't hard. Wiring up the Thrift network stuff is
a little challenging, but knowing where to start helps.

Running the examples
====================

1. `$ ruby -Ilib bin/stark examples/health.thrift > examples/health.rb`
2. `$ ruby -Ilib -Iexamples -rthrift examples/server.rb &`
3. `$ ruby -Ilib -Iexamples -rthrift examples/client.rb`

Write the Thrift IDL
====================

The first thing you need to do is write a definition for your Thrift service.
Here are some good examples:

* health check
* profile
* thrift spec

Now generate the Ruby for your client or server:

```
stark awesome.thrift > awesome.rb
```

Write a client
==============

* Require the generated Thrift code
* Require Thrift
* Use something like these magical four lines

Write a service
===============

* Require generated Thrift code and `thrift`
* Use more magical codes

Where to go next?
=================

* Thrift concepts

