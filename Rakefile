# -*- ruby -*-

require 'rubygems'
require 'hoe'

# Hoe.plugin :compiler
# Hoe.plugin :gem_prelude_sucks
# Hoe.plugin :inline
# Hoe.plugin :kpeg
# Hoe.plugin :racc
# Hoe.plugin :rcov
# Hoe.plugin :rubyforge

Hoe.spec 'thrift-optz' do
  developer('Evan Phoenix', 'evan@phx.io')
end

task :parser do
  sh "kpeg -o lib/thrift_optz/raw_parser.rb -s -f lib/thrift_optz/thrift.kpeg"
end

task :test => :parser

# vim: syntax=ruby
