module Stark
end

require 'set'
require 'stark/raw_parser'

class Stark::Parser
  def self.expand(ast)
    out = []

    ast.each do |elem|
      case elem
        when AST::Include
          data = Stark::Parser.read_file(elem.path)
          out += expand(Stark::Parser.ast(data))
        else
          out << elem
      end
    end

    out
  end

  def ast
    raise_error unless parse
    Stark::Parser.expand result
  end

  def self.ast(arg)
    parser = Stark::Parser.new arg
    parser.ast
  end

  def self.read_file(file)
    @@include_path ||= Set.new([Dir.pwd])
    if file.respond_to?(:read)
      @@include_path << File.dirname(File.expand_path(file.path, Dir.pwd)) if file.respond_to?(:path)
      return file.read
    else
      @@include_path << File.dirname(File.expand_path(file, Dir.pwd))
      fn = (@@include_path.map { |path| File.expand_path(file, path) }.detect { |fn| File.exist?(fn) }) || file
      File.read fn
    end
  end
end
