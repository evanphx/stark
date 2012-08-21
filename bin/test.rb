require 'rubygems'
require 'kpeg'

file = File.expand_path("../thrift.kpeg", __FILE__)
name = "GlassParser"

grammar = KPeg.load_grammar(file)

cg = KPeg::CodeGenerator.new name, grammar, true

code = cg.output

Object.module_eval code

data = File.read ARGV.shift

gp = GlassParser.new data
unless gp.parse
  gp.raise_error
end

require 'ast'
require 'ruby'

class Reprint
  def process_namespace(ns)
    puts "namespace #{ns.lang} #{ns.namespace}"
    puts
  end

  def process_include(inc)
    puts "include \"#{inc.file}\""
  end

  def process_struct(str)
    puts "struct #{str.name} {"
    str.fields.each do |f|
      puts "  #{f.index}: #{f.type} #{f.name}"
    end
    puts "}"
    puts
  end

  def process_service(serv)
    puts "service #{serv.name} {"
    serv.functions.each do |func|
      args = func.arguments.map { |f| "#{f.index}: #{f.type} #{f.name}" }
      puts "  #{func.return_type} #{func.name}(#{args.join(', ')})"
    end
    puts "}"
  end
end

puts "Parsed!"

p gp.result

gp.result.each { |i| i.accept Reprint.new }

gp.result.each { |i| i.accept Ruby.new }
