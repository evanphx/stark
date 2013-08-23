# -*- ruby -*-

require 'hoe'

# Don't turn on warnings, output is very ugly w/ generated code
Hoe::RUBY_FLAGS.sub! /-w/, ''

Hoe.plugin :travis
Hoe.plugin :gemspec
Hoe.plugin :git

Hoe.spec 'stark' do |spec|
  developer('Evan Phoenix', 'evan@phx.io')

  # thrift 0.9.1 had an unnecessary runtime dependency on thin
  dependency "thrift", ["~> 0.9.0", "!= 0.9.1"]
  readme_file = "README.md"

  spec.testlib = :testunit if spec.respond_to?(:testlib)
end

desc 'Run kpeg to generate new parser'
task :parser do
  sh "kpeg -o lib/stark/raw_parser.rb -s -f lib/stark/thrift.kpeg"
end
# vim: syntax=ruby
