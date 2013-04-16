# stark [![Build Status](https://travis-ci.org/evanphx/stark.png)](https://travis-ci.org/evanphx/stark)

* http://github.com/evanphx/stark 

## DESCRIPTION:

Optimized thrift bindings for ruby.

## FEATURES/PROBLEMS:

* Generates much more straightforward code for thrift clients and servers
  than the default thrift bindings for ruby.

## SYNOPSIS:

```
  $ stark service.thrift service.rb
```

```ruby
  require 'service'
```

  OR

```ruby
  Stark.materialize "service.thrift"
```

  Use `Service::Client` and
[`Service::Processor`](http://thrift.apache.org/docs/concepts/) like the default thrift
  docs describe them.

## REQUIREMENTS:

* thrift gem
* .thrift files

## INSTALL:

* gem install stark


## More in depth

The two main advantages of using Stark are that it allows you to not
have to convert thrift files ahead of time and the generated Ruby code is of
higher quality than the output of the Thrift Ruby gem.

### How to

When using `Stark.materialize` on a `.thrift` file, the file gets parsed
and converted into Ruby code that is available right away for you to
use.

Lets take this example thrift file:

```
struct User {
  1: required i32 id
  2: string firstName
  3: string lastName
}

exception UserNotFound {
  1: i32 errorCode
  2: string errorMessage
}

service GetUser {
  User fetchUser(1: string email) throws (1: UserNotFound e)
}
```

Stark will generate the equivalent of the following code:

```ruby
class User < Stark::Struct
  attr_reader :id, :firstName, :lastName
end

class UserNotFound < Stark::Exception
  attr_reader :errorCode, :errorMessage
end

module GetUser

  class Client < Stark::Client
    def fetchUser(email)
      # code to make the RPC call, handle errors etc..
    end
  end

  class Processor < Stark::Processor
    def process_fetchUser(seqid, ip, op)
    end
  end

end
```

#### Namespacing

While the generated code above is great, it might conflict with code you
already have in your application. To avoid conflicts, you can namespace
your materialized thrift examples.

```ruby
module MyApp; end
Stark.materialize "example.thrift", MyApp
```

The newly generated `GetUser` class is now generated under the provided
namespace: `MyApp::GetUser`.

Note that materializing a thrift file from within a module or a class
will still generate the code at the top level unless you specify a 
namespace.


### Debugging

Spark will output some valuable (albeit verbose) debugging information
if you set the `STARK_DEBUG` environment variable.

```
$ STARK_DEBUG=true ruby code_using_stark.rb
``` 

## DEVELOPERS:

After checking out the source, run:

```
  $ rake newb
```

This task will install any missing dependencies, run the tests/specs,
and generate the RDoc.

## LICENSE:

(The MIT License)

Copyright (c) 2013 Evan Phoenix

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
