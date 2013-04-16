# -*- ruby -*-

require 'hoe'

# Don't turn on warnings, output is very ugly w/ generated code
Hoe::RUBY_FLAGS.sub! /-w/, ''

Hoe.plugin :travis
Hoe.plugin :gemspec
Hoe.plugin :git

Hoe.spec 'stark' do
  developer('Evan Phoenix', 'evan@phx.io')

  dependency "thrift", "~> 0.9.0"
  readme_file = "README.md"
end

task :parser do
  sh "kpeg -o lib/stark/raw_parser.rb -s -f lib/stark/thrift.kpeg"
end

# vim: syntax=ruby
