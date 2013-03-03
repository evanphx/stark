module Stark
end

require 'stark/raw_parser'

class Stark::Parser
  def self.expand(ast)
    out = []

    ast.each do |elem|
      case elem
      when AST::Include
        data = File.read elem.path
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
end
