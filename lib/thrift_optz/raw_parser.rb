class ThriftOptz::Parser
  # :stopdoc:

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end



    # Prepares for parsing +str+.  If you define a custom initialize you must
    # call this method before #parse
    def setup_parser(str, debug=false)
      @string = str
      @pos = 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @failed_rule = nil
      @failing_rule_offset = -1

      setup_foreign_grammar
    end

    attr_reader :string
    attr_reader :failing_rule_offset
    attr_accessor :result, :pos

    
    def current_column(target=pos)
      if c = string.rindex("\n", target-1)
        return target - c - 1
      end

      target + 1
    end

    def current_line(target=pos)
      cur_offset = 0
      cur_line = 0

      string.each_line do |line|
        cur_line += 1
        cur_offset += line.size
        return cur_line if cur_offset >= target
      end

      -1
    end

    def lines
      lines = []
      string.each_line { |l| lines << l }
      lines
    end



    def get_text(start)
      @string[start..@pos-1]
    end

    def show_pos
      width = 10
      if @pos < width
        "#{@pos} (\"#{@string[0,@pos]}\" @ \"#{@string[@pos,width]}\")"
      else
        "#{@pos} (\"... #{@string[@pos - width, width]}\" @ \"#{@string[@pos,width]}\")"
      end
    end

    def failure_info
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "line #{l}, column #{c}: failed rule '#{info.name}' = '#{info.rendered}'"
      else
        "line #{l}, column #{c}: failed rule '#{@failed_rule}'"
      end
    end

    def failure_caret
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      line = lines[l-1]
      "#{line}\n#{' ' * (c - 1)}^"
    end

    def failure_character
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset
      lines[l-1][c-1, 1]
    end

    def failure_oneline
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      char = lines[l-1][c-1, 1]

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "@#{l}:#{c} failed rule '#{info.name}', got '#{char}'"
      else
        "@#{l}:#{c} failed rule '#{@failed_rule}', got '#{char}'"
      end
    end

    class ParseError < RuntimeError
    end

    def raise_error
      raise ParseError, failure_oneline
    end

    def show_error(io=STDOUT)
      error_pos = @failing_rule_offset
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "On line #{line_no}, column #{col_no}:"

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        io.puts "Failed to match '#{info.rendered}' (rule '#{info.name}')"
      else
        io.puts "Failed to match rule '#{@failed_rule}'"
      end

      io.puts "Got: #{string[error_pos,1].inspect}"
      line = lines[line_no-1]
      io.puts "=> #{line}"
      io.print(" " * (col_no + 3))
      io.puts "^"
    end

    def set_failed_rule(name)
      if @pos > @failing_rule_offset
        @failed_rule = name
        @failing_rule_offset = @pos
      end
    end

    attr_reader :failed_rule

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def scan(reg)
      if m = reg.match(@string[@pos..-1])
        width = m.end(0)
        @pos += width
        return true
      end

      return nil
    end

    if "".respond_to? :getbyte
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string.getbyte @pos
        @pos += 1
        s
      end
    else
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string[@pos]
        @pos += 1
        s
      end
    end

    def parse(rule=nil)
      # We invoke the rules indirectly via apply
      # instead of by just calling them as methods because
      # if the rules use left recursion, apply needs to
      # manage that.

      if !rule
        apply(:_root)
      else
        method = rule.gsub("-","_hyphen_")
        apply :"_#{method}"
      end
    end

    class MemoEntry
      def initialize(ans, pos)
        @ans = ans
        @pos = pos
        @result = nil
        @set = false
        @left_rec = false
      end

      attr_reader :ans, :pos, :result, :set
      attr_accessor :left_rec

      def move!(ans, pos, result)
        @ans = ans
        @pos = pos
        @result = result
        @set = true
        @left_rec = false
      end
    end

    def external_invoke(other, rule, *args)
      old_pos = @pos
      old_string = @string

      @pos = other.pos
      @string = other.string

      begin
        if val = __send__(rule, *args)
          other.pos = @pos
          other.result = @result
        else
          other.set_failed_rule "#{self.class}##{rule}"
        end
        val
      ensure
        @pos = old_pos
        @string = old_string
      end
    end

    def apply_with_args(rule, *args)
      memo_key = [rule, args]
      if m = @memoizations[memo_key][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[memo_key][@pos] = m
        start_pos = @pos

        ans = __send__ rule, *args

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, args, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def apply(rule)
      if m = @memoizations[rule][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ rule

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, nil, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def grow_lr(rule, args, start_pos, m)
      while true
        @pos = start_pos
        @result = m.result

        if args
          ans = __send__ rule, *args
        else
          ans = __send__ rule
        end
        return nil unless ans

        break if @pos <= m.pos

        m.move! ans, @pos, @result
      end

      @result = m.result
      @pos = m.pos
      return m.ans
    end

    class RuleInfo
      def initialize(name, rendered)
        @name = name
        @rendered = rendered
      end

      attr_reader :name, :rendered
    end

    def self.rule_info(name, rendered)
      RuleInfo.new(name, rendered)
    end


  # :startdoc:
  # :stopdoc:

  module AST
    class Node; end
    class Comment < Node
      def initialize(text)
        @text = text
      end
      attr_reader :text
    end
    class ConstDouble < Node
      def initialize(value)
        @value = value
      end
      attr_reader :value
    end
    class ConstIdentifier < Node
      def initialize(value)
        @value = value
      end
      attr_reader :value
    end
    class ConstInt < Node
      def initialize(value)
        @value = value
      end
      attr_reader :value
    end
    class ConstList < Node
      def initialize(values)
        @values = values
      end
      attr_reader :values
    end
    class ConstMap < Node
      def initialize(values)
        @values = values
      end
      attr_reader :values
    end
    class ConstString < Node
      def initialize(value)
        @value = value
      end
      attr_reader :value
    end
    class Enum < Node
      def initialize(name, values)
        @name = name
        @values = values
      end
      attr_reader :name
      attr_reader :values
    end
    class Exception < Node
      def initialize(name, fields)
        @name = name
        @fields = fields
      end
      attr_reader :name
      attr_reader :fields
    end
    class Field < Node
      def initialize(index, type, name, value, options)
        @index = index
        @type = type
        @name = name
        @value = value
        @options = options
      end
      attr_reader :index
      attr_reader :type
      attr_reader :name
      attr_reader :value
      attr_reader :options
    end
    class Function < Node
      def initialize(name, return_type, arguments)
        @name = name
        @return_type = return_type
        @arguments = arguments
      end
      attr_reader :name
      attr_reader :return_type
      attr_reader :arguments
    end
    class Include < Node
      def initialize(path)
        @path = path
      end
      attr_reader :path
    end
    class List < Node
      def initialize(value)
        @value = value
      end
      attr_reader :value
    end
    class Map < Node
      def initialize(key, value)
        @key = key
        @value = value
      end
      attr_reader :key
      attr_reader :value
    end
    class Namespace < Node
      def initialize(lang, namespace)
        @lang = lang
        @namespace = namespace
      end
      attr_reader :lang
      attr_reader :namespace
    end
    class Service < Node
      def initialize(name, functions)
        @name = name
        @functions = functions
      end
      attr_reader :name
      attr_reader :functions
    end
    class Set < Node
      def initialize(value)
        @value = value
      end
      attr_reader :value
    end
    class Struct < Node
      def initialize(type, name, fields)
        @type = type
        @name = name
        @fields = fields
      end
      attr_reader :type
      attr_reader :name
      attr_reader :fields
    end
  end
  def comment(text)
    AST::Comment.new(text)
  end
  def const_dbl(value)
    AST::ConstDouble.new(value)
  end
  def const_id(value)
    AST::ConstIdentifier.new(value)
  end
  def const_int(value)
    AST::ConstInt.new(value)
  end
  def const_list(values)
    AST::ConstList.new(values)
  end
  def const_map(values)
    AST::ConstMap.new(values)
  end
  def const_str(value)
    AST::ConstString.new(value)
  end
  def enum(name, values)
    AST::Enum.new(name, values)
  end
  def exception(name, fields)
    AST::Exception.new(name, fields)
  end
  def field(index, type, name, value, options)
    AST::Field.new(index, type, name, value, options)
  end
  def function(name, return_type, arguments)
    AST::Function.new(name, return_type, arguments)
  end
  def include(path)
    AST::Include.new(path)
  end
  def list(value)
    AST::List.new(value)
  end
  def map(key, value)
    AST::Map.new(key, value)
  end
  def namespace(lang, namespace)
    AST::Namespace.new(lang, namespace)
  end
  def service(name, functions)
    AST::Service.new(name, functions)
  end
  def set(value)
    AST::Set.new(value)
  end
  def struct(type, name, fields)
    AST::Struct.new(type, name, fields)
  end
  def setup_foreign_grammar; end

  # intconstant = /([+-]?[0-9]+)/
  def _intconstant
    _tmp = scan(/\A(?-mix:([+-]?[0-9]+))/)
    set_failed_rule :_intconstant unless _tmp
    return _tmp
  end

  # hexconstant = /("0x"[0-9A-Fa-f]+)/
  def _hexconstant
    _tmp = scan(/\A(?-mix:("0x"[0-9A-Fa-f]+))/)
    set_failed_rule :_hexconstant unless _tmp
    return _tmp
  end

  # dubconstant = (/([+-]?[0-9]+(\.[0-9]+)([eE][+-]?[0-9]+)?)/ | /([+-]?[0-9]+([eE][+-]?[0-9]+))/ | /([+-]?(\.[0-9]+)([eE][+-]?[0-9]+)?)/)
  def _dubconstant

    _save = self.pos
    while true # choice
      _tmp = scan(/\A(?-mix:([+-]?[0-9]+(\.[0-9]+)([eE][+-]?[0-9]+)?))/)
      break if _tmp
      self.pos = _save
      _tmp = scan(/\A(?-mix:([+-]?[0-9]+([eE][+-]?[0-9]+)))/)
      break if _tmp
      self.pos = _save
      _tmp = scan(/\A(?-mix:([+-]?(\.[0-9]+)([eE][+-]?[0-9]+)?))/)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_dubconstant unless _tmp
    return _tmp
  end

  # identifier = /([a-zA-Z_][\.a-zA-Z_0-9]*)/
  def _identifier
    _tmp = scan(/\A(?-mix:([a-zA-Z_][\.a-zA-Z_0-9]*))/)
    set_failed_rule :_identifier unless _tmp
    return _tmp
  end

  # whitespace = /([ \t\r\n]*)/
  def _whitespace
    _tmp = scan(/\A(?-mix:([ \t\r\n]*))/)
    set_failed_rule :_whitespace unless _tmp
    return _tmp
  end

  # st_identifier = /([a-zA-Z-][\.a-zA-Z_0-9-]*)/
  def _st_identifier
    _tmp = scan(/\A(?-mix:([a-zA-Z-][\.a-zA-Z_0-9-]*))/)
    set_failed_rule :_st_identifier unless _tmp
    return _tmp
  end

  # literal_begin = /(['\"])/
  def _literal_begin
    _tmp = scan(/\A(?-mix:(['\"]))/)
    set_failed_rule :_literal_begin unless _tmp
    return _tmp
  end

  # reserved = ("BEGIN" | "END" | "__CLASS__" | "__DIR__" | "__FILE__" | "__FUNCTION__" | "__LINE__" | "__METHOD__" | "__NAMESPACE__" | "abstract" | "alias" | "and" | "args" | "as" | "assert" | "begin" | "break" | "case" | "catch" | "class" | "clone" | "continue" | "declare" | "def" | "default" | "del" | "delete" | "do" | "dynamic" | "elif" | "else" | "elseif" | "elsif" | "end" | "enddeclare" | "endfor" | "endforeach" | "endif" | "endswitch" | "endwhile" | "ensure" | "except" | "exec" | "finally" | "float" | "for" | "foreach" | "function" | "global" | "goto" | "if" | "implements" | "import" | "in" | "inline" | "instanceof" | "interface" | "is" | "lambda" | "module" | "native" | "new" | "next" | "nil" | "not" | "or" | "pass" | "public" | "print" | "private" | "protected" | "public" | "raise" | "redo" | "rescue" | "retry" | "register" | "return" | "self" | "sizeof" | "static" | "super" | "switch" | "synchronized" | "then" | "this" | "throw" | "transient" | "try" | "undef" | "union" | "unless" | "unsigned" | "until" | "use" | "var" | "virtual" | "volatile" | "when" | "while" | "with" | "xor" | "yield")
  def _reserved

    _save = self.pos
    while true # choice
      _tmp = match_string("BEGIN")
      break if _tmp
      self.pos = _save
      _tmp = match_string("END")
      break if _tmp
      self.pos = _save
      _tmp = match_string("__CLASS__")
      break if _tmp
      self.pos = _save
      _tmp = match_string("__DIR__")
      break if _tmp
      self.pos = _save
      _tmp = match_string("__FILE__")
      break if _tmp
      self.pos = _save
      _tmp = match_string("__FUNCTION__")
      break if _tmp
      self.pos = _save
      _tmp = match_string("__LINE__")
      break if _tmp
      self.pos = _save
      _tmp = match_string("__METHOD__")
      break if _tmp
      self.pos = _save
      _tmp = match_string("__NAMESPACE__")
      break if _tmp
      self.pos = _save
      _tmp = match_string("abstract")
      break if _tmp
      self.pos = _save
      _tmp = match_string("alias")
      break if _tmp
      self.pos = _save
      _tmp = match_string("and")
      break if _tmp
      self.pos = _save
      _tmp = match_string("args")
      break if _tmp
      self.pos = _save
      _tmp = match_string("as")
      break if _tmp
      self.pos = _save
      _tmp = match_string("assert")
      break if _tmp
      self.pos = _save
      _tmp = match_string("begin")
      break if _tmp
      self.pos = _save
      _tmp = match_string("break")
      break if _tmp
      self.pos = _save
      _tmp = match_string("case")
      break if _tmp
      self.pos = _save
      _tmp = match_string("catch")
      break if _tmp
      self.pos = _save
      _tmp = match_string("class")
      break if _tmp
      self.pos = _save
      _tmp = match_string("clone")
      break if _tmp
      self.pos = _save
      _tmp = match_string("continue")
      break if _tmp
      self.pos = _save
      _tmp = match_string("declare")
      break if _tmp
      self.pos = _save
      _tmp = match_string("def")
      break if _tmp
      self.pos = _save
      _tmp = match_string("default")
      break if _tmp
      self.pos = _save
      _tmp = match_string("del")
      break if _tmp
      self.pos = _save
      _tmp = match_string("delete")
      break if _tmp
      self.pos = _save
      _tmp = match_string("do")
      break if _tmp
      self.pos = _save
      _tmp = match_string("dynamic")
      break if _tmp
      self.pos = _save
      _tmp = match_string("elif")
      break if _tmp
      self.pos = _save
      _tmp = match_string("else")
      break if _tmp
      self.pos = _save
      _tmp = match_string("elseif")
      break if _tmp
      self.pos = _save
      _tmp = match_string("elsif")
      break if _tmp
      self.pos = _save
      _tmp = match_string("end")
      break if _tmp
      self.pos = _save
      _tmp = match_string("enddeclare")
      break if _tmp
      self.pos = _save
      _tmp = match_string("endfor")
      break if _tmp
      self.pos = _save
      _tmp = match_string("endforeach")
      break if _tmp
      self.pos = _save
      _tmp = match_string("endif")
      break if _tmp
      self.pos = _save
      _tmp = match_string("endswitch")
      break if _tmp
      self.pos = _save
      _tmp = match_string("endwhile")
      break if _tmp
      self.pos = _save
      _tmp = match_string("ensure")
      break if _tmp
      self.pos = _save
      _tmp = match_string("except")
      break if _tmp
      self.pos = _save
      _tmp = match_string("exec")
      break if _tmp
      self.pos = _save
      _tmp = match_string("finally")
      break if _tmp
      self.pos = _save
      _tmp = match_string("float")
      break if _tmp
      self.pos = _save
      _tmp = match_string("for")
      break if _tmp
      self.pos = _save
      _tmp = match_string("foreach")
      break if _tmp
      self.pos = _save
      _tmp = match_string("function")
      break if _tmp
      self.pos = _save
      _tmp = match_string("global")
      break if _tmp
      self.pos = _save
      _tmp = match_string("goto")
      break if _tmp
      self.pos = _save
      _tmp = match_string("if")
      break if _tmp
      self.pos = _save
      _tmp = match_string("implements")
      break if _tmp
      self.pos = _save
      _tmp = match_string("import")
      break if _tmp
      self.pos = _save
      _tmp = match_string("in")
      break if _tmp
      self.pos = _save
      _tmp = match_string("inline")
      break if _tmp
      self.pos = _save
      _tmp = match_string("instanceof")
      break if _tmp
      self.pos = _save
      _tmp = match_string("interface")
      break if _tmp
      self.pos = _save
      _tmp = match_string("is")
      break if _tmp
      self.pos = _save
      _tmp = match_string("lambda")
      break if _tmp
      self.pos = _save
      _tmp = match_string("module")
      break if _tmp
      self.pos = _save
      _tmp = match_string("native")
      break if _tmp
      self.pos = _save
      _tmp = match_string("new")
      break if _tmp
      self.pos = _save
      _tmp = match_string("next")
      break if _tmp
      self.pos = _save
      _tmp = match_string("nil")
      break if _tmp
      self.pos = _save
      _tmp = match_string("not")
      break if _tmp
      self.pos = _save
      _tmp = match_string("or")
      break if _tmp
      self.pos = _save
      _tmp = match_string("pass")
      break if _tmp
      self.pos = _save
      _tmp = match_string("public")
      break if _tmp
      self.pos = _save
      _tmp = match_string("print")
      break if _tmp
      self.pos = _save
      _tmp = match_string("private")
      break if _tmp
      self.pos = _save
      _tmp = match_string("protected")
      break if _tmp
      self.pos = _save
      _tmp = match_string("public")
      break if _tmp
      self.pos = _save
      _tmp = match_string("raise")
      break if _tmp
      self.pos = _save
      _tmp = match_string("redo")
      break if _tmp
      self.pos = _save
      _tmp = match_string("rescue")
      break if _tmp
      self.pos = _save
      _tmp = match_string("retry")
      break if _tmp
      self.pos = _save
      _tmp = match_string("register")
      break if _tmp
      self.pos = _save
      _tmp = match_string("return")
      break if _tmp
      self.pos = _save
      _tmp = match_string("self")
      break if _tmp
      self.pos = _save
      _tmp = match_string("sizeof")
      break if _tmp
      self.pos = _save
      _tmp = match_string("static")
      break if _tmp
      self.pos = _save
      _tmp = match_string("super")
      break if _tmp
      self.pos = _save
      _tmp = match_string("switch")
      break if _tmp
      self.pos = _save
      _tmp = match_string("synchronized")
      break if _tmp
      self.pos = _save
      _tmp = match_string("then")
      break if _tmp
      self.pos = _save
      _tmp = match_string("this")
      break if _tmp
      self.pos = _save
      _tmp = match_string("throw")
      break if _tmp
      self.pos = _save
      _tmp = match_string("transient")
      break if _tmp
      self.pos = _save
      _tmp = match_string("try")
      break if _tmp
      self.pos = _save
      _tmp = match_string("undef")
      break if _tmp
      self.pos = _save
      _tmp = match_string("union")
      break if _tmp
      self.pos = _save
      _tmp = match_string("unless")
      break if _tmp
      self.pos = _save
      _tmp = match_string("unsigned")
      break if _tmp
      self.pos = _save
      _tmp = match_string("until")
      break if _tmp
      self.pos = _save
      _tmp = match_string("use")
      break if _tmp
      self.pos = _save
      _tmp = match_string("var")
      break if _tmp
      self.pos = _save
      _tmp = match_string("virtual")
      break if _tmp
      self.pos = _save
      _tmp = match_string("volatile")
      break if _tmp
      self.pos = _save
      _tmp = match_string("when")
      break if _tmp
      self.pos = _save
      _tmp = match_string("while")
      break if _tmp
      self.pos = _save
      _tmp = match_string("with")
      break if _tmp
      self.pos = _save
      _tmp = match_string("xor")
      break if _tmp
      self.pos = _save
      _tmp = match_string("yield")
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_reserved unless _tmp
    return _tmp
  end

  # tok_int_constant = (< intconstant > { text.to_i } | < hexconstant > { text.to_i } | "false" { 0 } | "true" { 1 })
  def _tok_int_constant

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _text_start = self.pos
        _tmp = apply(:_intconstant)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  text.to_i ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _text_start = self.pos
        _tmp = apply(:_hexconstant)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  text.to_i ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = match_string("false")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  0 ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = match_string("true")
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  1 ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_tok_int_constant unless _tmp
    return _tmp
  end

  # tok_dub_constant = dubconstant:f { f.to_f }
  def _tok_dub_constant

    _save = self.pos
    while true # sequence
      _tmp = apply(:_dubconstant)
      f = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  f.to_f ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_tok_dub_constant unless _tmp
    return _tmp
  end

  # tok_identifier = < identifier > {text}
  def _tok_identifier

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = apply(:_identifier)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_tok_identifier unless _tmp
    return _tmp
  end

  # tok_st_identifier = st_identifier
  def _tok_st_identifier
    _tmp = apply(:_st_identifier)
    set_failed_rule :_tok_st_identifier unless _tmp
    return _tmp
  end

  # escapes = ("\\r" { "\r" } | "\\n" { "\n" } | "\\t" { "\t" } | "\\\"" { "\"" } | "\\'" { "'" } | "\\\\" { "\\" })
  def _escapes

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\\r")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  "\r" ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("\\n")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  "\n" ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = match_string("\\t")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  "\t" ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = match_string("\\\"")
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  "\"" ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _tmp = match_string("\\'")
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin;  "'" ; end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save6 = self.pos
      while true # sequence
        _tmp = match_string("\\\\")
        unless _tmp
          self.pos = _save6
          break
        end
        @result = begin;  "\\" ; end
        _tmp = true
        unless _tmp
          self.pos = _save6
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_escapes unless _tmp
    return _tmp
  end

  # tok_literal = ("\"" < (escapes | !"\"" .)* > "\"" {text} | "'" < (escapes | !"'" .)* > "'" {text})
  def _tok_literal

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\"")
        unless _tmp
          self.pos = _save1
          break
        end
        _text_start = self.pos
        while true

          _save3 = self.pos
          while true # choice
            _tmp = apply(:_escapes)
            break if _tmp
            self.pos = _save3

            _save4 = self.pos
            while true # sequence
              _save5 = self.pos
              _tmp = match_string("\"")
              _tmp = _tmp ? nil : true
              self.pos = _save5
              unless _tmp
                self.pos = _save4
                break
              end
              _tmp = get_byte
              unless _tmp
                self.pos = _save4
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save3
            break
          end # end choice

          break unless _tmp
        end
        _tmp = true
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("\"")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; text; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save6 = self.pos
      while true # sequence
        _tmp = match_string("'")
        unless _tmp
          self.pos = _save6
          break
        end
        _text_start = self.pos
        while true

          _save8 = self.pos
          while true # choice
            _tmp = apply(:_escapes)
            break if _tmp
            self.pos = _save8

            _save9 = self.pos
            while true # sequence
              _save10 = self.pos
              _tmp = match_string("'")
              _tmp = _tmp ? nil : true
              self.pos = _save10
              unless _tmp
                self.pos = _save9
                break
              end
              _tmp = get_byte
              unless _tmp
                self.pos = _save9
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save8
            break
          end # end choice

          break unless _tmp
        end
        _tmp = true
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save6
          break
        end
        _tmp = match_string("'")
        unless _tmp
          self.pos = _save6
          break
        end
        @result = begin; text; end
        _tmp = true
        unless _tmp
          self.pos = _save6
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_tok_literal unless _tmp
    return _tmp
  end

  # - = /[ \t]+/
  def __hyphen_
    _tmp = scan(/\A(?-mix:[ \t]+)/)
    set_failed_rule :__hyphen_ unless _tmp
    return _tmp
  end

  # osp = /[ \t]*/
  def _osp
    _tmp = scan(/\A(?-mix:[ \t]*)/)
    set_failed_rule :_osp unless _tmp
    return _tmp
  end

  # bsp = /[\s]+/
  def _bsp
    _tmp = scan(/\A(?-mix:[\s]+)/)
    set_failed_rule :_bsp unless _tmp
    return _tmp
  end

  # obsp = /[\s]*/
  def _obsp
    _tmp = scan(/\A(?-mix:[\s]*)/)
    set_failed_rule :_obsp unless _tmp
    return _tmp
  end

  # root = Program !.
  def _root

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Program)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = get_byte
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # Program = Element*:a { a }
  def _Program

    _save = self.pos
    while true # sequence
      _ary = []
      while true
        _tmp = apply(:_Element)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      a = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  a ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Program unless _tmp
    return _tmp
  end

  # CComment = "/*" < (!"*/" .)* > "*/" obsp {comment(text)}
  def _CComment

    _save = self.pos
    while true # sequence
      _tmp = match_string("/*")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      while true

        _save2 = self.pos
        while true # sequence
          _save3 = self.pos
          _tmp = match_string("*/")
          _tmp = _tmp ? nil : true
          self.pos = _save3
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = get_byte
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break unless _tmp
      end
      _tmp = true
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("*/")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; comment(text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_CComment unless _tmp
    return _tmp
  end

  # HComment = "#" < (!"\n" .)* > bsp {comment(text)}
  def _HComment

    _save = self.pos
    while true # sequence
      _tmp = match_string("#")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      while true

        _save2 = self.pos
        while true # sequence
          _save3 = self.pos
          _tmp = match_string("\n")
          _tmp = _tmp ? nil : true
          self.pos = _save3
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = get_byte
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break unless _tmp
      end
      _tmp = true
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_bsp)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; comment(text); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_HComment unless _tmp
    return _tmp
  end

  # Comment = (CComment | HComment)
  def _Comment

    _save = self.pos
    while true # choice
      _tmp = apply(:_CComment)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_HComment)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Comment unless _tmp
    return _tmp
  end

  # CaptureDocText = {}
  def _CaptureDocText
    @result = begin; ; end
    _tmp = true
    set_failed_rule :_CaptureDocText unless _tmp
    return _tmp
  end

  # DestroyDocText = {}
  def _DestroyDocText
    @result = begin; ; end
    _tmp = true
    set_failed_rule :_DestroyDocText unless _tmp
    return _tmp
  end

  # HeaderList = (HeaderList Header | Header)
  def _HeaderList

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_HeaderList)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_Header)
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_Header)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_HeaderList unless _tmp
    return _tmp
  end

  # Element = (Comment | Header bsp | Definition bsp)
  def _Element

    _save = self.pos
    while true # choice
      _tmp = apply(:_Comment)
      break if _tmp
      self.pos = _save

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_Header)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_bsp)
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_Definition)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_bsp)
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Element unless _tmp
    return _tmp
  end

  # Header = (Include | Namespace)
  def _Header

    _save = self.pos
    while true # choice
      _tmp = apply(:_Include)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Namespace)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Header unless _tmp
    return _tmp
  end

  # Namespace = ("namespace" - tok_identifier:l - tok_identifier:n {namespace(l,n)} | "namespace" - "*" - tok_identifier:n {namespace(nil,n)})
  def _Namespace

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("namespace")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_tok_identifier)
        l = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_tok_identifier)
        n = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; namespace(l,n); end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("namespace")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("*")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_tok_identifier)
        n = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; namespace(nil,n); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Namespace unless _tmp
    return _tmp
  end

  # Include = "include" - tok_literal:f {include(f)}
  def _Include

    _save = self.pos
    while true # sequence
      _tmp = match_string("include")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_literal)
      f = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; include(f); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Include unless _tmp
    return _tmp
  end

  # DefinitionList = DefinitionList CaptureDocText Definition
  def _DefinitionList

    _save = self.pos
    while true # sequence
      _tmp = apply(:_DefinitionList)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CaptureDocText)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Definition)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_DefinitionList unless _tmp
    return _tmp
  end

  # Definition = (Const | TypeDefinition | Service)
  def _Definition

    _save = self.pos
    while true # choice
      _tmp = apply(:_Const)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_TypeDefinition)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Service)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Definition unless _tmp
    return _tmp
  end

  # TypeDefinition = (Typedef | Enum | Senum | Struct | Xception)
  def _TypeDefinition

    _save = self.pos
    while true # choice
      _tmp = apply(:_Typedef)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Enum)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Senum)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Struct)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Xception)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_TypeDefinition unless _tmp
    return _tmp
  end

  # Typedef = "typedef" - FieldType tok_identifier
  def _Typedef

    _save = self.pos
    while true # sequence
      _tmp = match_string("typedef")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldType)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Typedef unless _tmp
    return _tmp
  end

  # CommaOrSemicolonOptional = ("," | ";")? obsp
  def _CommaOrSemicolonOptional

    _save = self.pos
    while true # sequence
      _save1 = self.pos

      _save2 = self.pos
      while true # choice
        _tmp = match_string(",")
        break if _tmp
        self.pos = _save2
        _tmp = match_string(";")
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_CommaOrSemicolonOptional unless _tmp
    return _tmp
  end

  # Enum = "enum" - tok_identifier:name osp "{" obsp EnumDefList:vals obsp "}" {enum(name, vals)}
  def _Enum

    _save = self.pos
    while true # sequence
      _tmp = match_string("enum")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      name = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_EnumDefList)
      vals = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; enum(name, vals); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Enum unless _tmp
    return _tmp
  end

  # EnumDefList = (EnumDefList:l EnumDef:e { l + [e] } | EnumDef:e { [e] })
  def _EnumDefList

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_EnumDefList)
        l = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_EnumDef)
        e = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  l + [e] ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_EnumDef)
        e = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [e] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_EnumDefList unless _tmp
    return _tmp
  end

  # EnumDef = (CaptureDocText tok_identifier "=" tok_int_constant CommaOrSemicolonOptional | CaptureDocText tok_identifier CommaOrSemicolonOptional)
  def _EnumDef

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_CaptureDocText)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_tok_identifier)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("=")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_tok_int_constant)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_CommaOrSemicolonOptional)
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_CaptureDocText)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_tok_identifier)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_CommaOrSemicolonOptional)
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_EnumDef unless _tmp
    return _tmp
  end

  # Senum = "senum" - tok_identifier "{" SenumDefList "}"
  def _Senum

    _save = self.pos
    while true # sequence
      _tmp = match_string("senum")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_SenumDefList)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Senum unless _tmp
    return _tmp
  end

  # SenumDefList = (SenumDefList SenumDef | nothing)
  def _SenumDefList

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_SenumDefList)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_SenumDef)
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_nothing)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_SenumDefList unless _tmp
    return _tmp
  end

  # SenumDef = tok_literal CommaOrSemicolonOptional
  def _SenumDef

    _save = self.pos
    while true # sequence
      _tmp = apply(:_tok_literal)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CommaOrSemicolonOptional)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_SenumDef unless _tmp
    return _tmp
  end

  # Const = "const" - FieldType tok_identifier "=" ConstValue CommaOrSemicolonOptional
  def _Const

    _save = self.pos
    while true # sequence
      _tmp = match_string("const")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldType)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("=")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_ConstValue)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CommaOrSemicolonOptional)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Const unless _tmp
    return _tmp
  end

  # ConstValue = (tok_int_constant:i {const_int(i)} | tok_literal:s {const_str(s)} | tok_identifier:i {const_id(i)} | ConstList | ConstMap | tok_dub_constant:d {const_dbl(d)})
  def _ConstValue

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_tok_int_constant)
        i = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; const_int(i); end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_tok_literal)
        s = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin; const_str(s); end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = apply(:_tok_identifier)
        i = @result
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin; const_id(i); end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_ConstList)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_ConstMap)
      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = apply(:_tok_dub_constant)
        d = @result
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin; const_dbl(d); end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_ConstValue unless _tmp
    return _tmp
  end

  # ConstList = "[" osp ConstListContents*:l osp "]" {const_list(l)}
  def _ConstList

    _save = self.pos
    while true # sequence
      _tmp = match_string("[")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _ary = []
      while true
        _tmp = apply(:_ConstListContents)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      l = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("]")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; const_list(l); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ConstList unless _tmp
    return _tmp
  end

  # ConstListContents = ConstValue:i CommaOrSemicolonOptional osp {i}
  def _ConstListContents

    _save = self.pos
    while true # sequence
      _tmp = apply(:_ConstValue)
      i = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CommaOrSemicolonOptional)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; i; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ConstListContents unless _tmp
    return _tmp
  end

  # ConstMap = "{" osp ConstMapContents*:m osp "}" {const_map(m)}
  def _ConstMap

    _save = self.pos
    while true # sequence
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _ary = []
      while true
        _tmp = apply(:_ConstMapContents)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      m = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; const_map(m); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ConstMap unless _tmp
    return _tmp
  end

  # ConstMapContents = ConstValue:k osp ":" osp ConstValue:v CommaOrSemicolonOptional { [k,v] }
  def _ConstMapContents

    _save = self.pos
    while true # sequence
      _tmp = apply(:_ConstValue)
      k = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(":")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_ConstValue)
      v = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CommaOrSemicolonOptional)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  [k,v] ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ConstMapContents unless _tmp
    return _tmp
  end

  # StructHead = < ("struct" | "union") > {text}
  def _StructHead

    _save = self.pos
    while true # sequence
      _text_start = self.pos

      _save1 = self.pos
      while true # choice
        _tmp = match_string("struct")
        break if _tmp
        self.pos = _save1
        _tmp = match_string("union")
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_StructHead unless _tmp
    return _tmp
  end

  # Struct = StructHead:t - tok_identifier:name - XsdAll? osp "{" obsp Comment? FieldList?:list obsp "}" {struct(t.to_sym,name,list)}
  def _Struct

    _save = self.pos
    while true # sequence
      _tmp = apply(:_StructHead)
      t = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      name = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_XsdAll)
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_Comment)
      unless _tmp
        _tmp = true
        self.pos = _save2
      end
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _tmp = apply(:_FieldList)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save3
      end
      list = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; struct(t.to_sym,name,list); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Struct unless _tmp
    return _tmp
  end

  # XsdAll = "xsd_all"
  def _XsdAll
    _tmp = match_string("xsd_all")
    set_failed_rule :_XsdAll unless _tmp
    return _tmp
  end

  # XsdOptional = ("xsd_optional" - | nothing)
  def _XsdOptional

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("xsd_optional")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_nothing)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_XsdOptional unless _tmp
    return _tmp
  end

  # XsdNillable = ("xsd_nillable" - | nothing)
  def _XsdNillable

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("xsd_nillable")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_nothing)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_XsdNillable unless _tmp
    return _tmp
  end

  # XsdAttributes = ("xsd_attrs" - "{" FieldList "}" | nothing)
  def _XsdAttributes

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("xsd_attrs")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("{")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_FieldList)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("}")
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_nothing)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_XsdAttributes unless _tmp
    return _tmp
  end

  # Xception = "exception" - tok_identifier:name osp "{" obsp FieldList?:list obsp "}" {exception(name, list)}
  def _Xception

    _save = self.pos
    while true # sequence
      _tmp = match_string("exception")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      name = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_FieldList)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      list = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; exception(name, list); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Xception unless _tmp
    return _tmp
  end

  # Service = "service" - tok_identifier:name - Extends? osp "{" obsp FunctionList?:funcs obsp "}" {service(name, funcs)}
  def _Service

    _save = self.pos
    while true # sequence
      _tmp = match_string("service")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      name = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_Extends)
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_FunctionList)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save2
      end
      funcs = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_obsp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; service(name, funcs); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Service unless _tmp
    return _tmp
  end

  # Extends = "extends" - tok_identifier
  def _Extends

    _save = self.pos
    while true # sequence
      _tmp = match_string("extends")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Extends unless _tmp
    return _tmp
  end

  # FunctionList = (FunctionList:l Function:f { l + [f] } | Function:f { [f] })
  def _FunctionList

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_FunctionList)
        l = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_Function)
        f = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  l + [f] ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_Function)
        f = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [f] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_FunctionList unless _tmp
    return _tmp
  end

  # Function = CaptureDocText OneWay? FunctionType:rt - tok_identifier:name osp "(" FieldList?:args ")" Throws? CommaOrSemicolonOptional {function(name, rt, args)}
  def _Function

    _save = self.pos
    while true # sequence
      _tmp = apply(:_CaptureDocText)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_OneWay)
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FunctionType)
      rt = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      name = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("(")
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_FieldList)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save2
      end
      args = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(")")
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _tmp = apply(:_Throws)
      unless _tmp
        _tmp = true
        self.pos = _save3
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CommaOrSemicolonOptional)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; function(name, rt, args); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Function unless _tmp
    return _tmp
  end

  # OneWay = ("oneway" | "async") -
  def _OneWay

    _save = self.pos
    while true # sequence

      _save1 = self.pos
      while true # choice
        _tmp = match_string("oneway")
        break if _tmp
        self.pos = _save1
        _tmp = match_string("async")
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_OneWay unless _tmp
    return _tmp
  end

  # Throws = "throws" - "(" FieldList ")"
  def _Throws

    _save = self.pos
    while true # sequence
      _tmp = match_string("throws")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("(")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldList)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(")")
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Throws unless _tmp
    return _tmp
  end

  # FieldList = (FieldList:l Field:f { l + [f] } | Field:f { [f] })
  def _FieldList

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_FieldList)
        l = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_Field)
        f = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  l + [f] ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_Field)
        f = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [f] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_FieldList unless _tmp
    return _tmp
  end

  # Field = CaptureDocText FieldIdentifier?:i osp FieldRequiredness?:req osp FieldType:t osp tok_identifier:n osp FieldValue?:val CommaOrSemicolonOptional {field(i,t,n,val,req)}
  def _Field

    _save = self.pos
    while true # sequence
      _tmp = apply(:_CaptureDocText)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_FieldIdentifier)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      i = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_FieldRequiredness)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save2
      end
      req = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldType)
      t = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_identifier)
      n = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _tmp = apply(:_FieldValue)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save3
      end
      val = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CommaOrSemicolonOptional)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; field(i,t,n,val,req); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Field unless _tmp
    return _tmp
  end

  # FieldIdentifier = tok_int_constant:n ":" {n}
  def _FieldIdentifier

    _save = self.pos
    while true # sequence
      _tmp = apply(:_tok_int_constant)
      n = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(":")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; n; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_FieldIdentifier unless _tmp
    return _tmp
  end

  # FieldRequiredness = < ("required" | "optional") > { [text] }
  def _FieldRequiredness

    _save = self.pos
    while true # sequence
      _text_start = self.pos

      _save1 = self.pos
      while true # choice
        _tmp = match_string("required")
        break if _tmp
        self.pos = _save1
        _tmp = match_string("optional")
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  [text] ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_FieldRequiredness unless _tmp
    return _tmp
  end

  # FieldValue = "=" osp ConstValue:e {e}
  def _FieldValue

    _save = self.pos
    while true # sequence
      _tmp = match_string("=")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_ConstValue)
      e = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; e; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_FieldValue unless _tmp
    return _tmp
  end

  # FunctionType = (FieldType | "void")
  def _FunctionType

    _save = self.pos
    while true # choice
      _tmp = apply(:_FieldType)
      break if _tmp
      self.pos = _save
      _tmp = match_string("void")
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_FunctionType unless _tmp
    return _tmp
  end

  # FieldType = (ContainerType | tok_identifier:n {n})
  def _FieldType

    _save = self.pos
    while true # choice
      _tmp = apply(:_ContainerType)
      break if _tmp
      self.pos = _save

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_tok_identifier)
        n = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin; n; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_FieldType unless _tmp
    return _tmp
  end

  # BaseType = SimpleBaseType:t TypeAnnotations {t}
  def _BaseType

    _save = self.pos
    while true # sequence
      _tmp = apply(:_SimpleBaseType)
      t = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_TypeAnnotations)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; t; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BaseType unless _tmp
    return _tmp
  end

  # SimpleBaseType = ("string" { :string } | "binary" { :binary } | "slist" { :slist } | "bool" { :bool } | "byte" { :byte } | "i16" { :i16 } | "i32" { :i32 } | "i64" { :i64 } | "double" { :double })
  def _SimpleBaseType

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("string")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  :string ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("binary")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  :binary ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = match_string("slist")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  :slist ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = match_string("bool")
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  :bool ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _tmp = match_string("byte")
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin;  :byte ; end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save6 = self.pos
      while true # sequence
        _tmp = match_string("i16")
        unless _tmp
          self.pos = _save6
          break
        end
        @result = begin;  :i16 ; end
        _tmp = true
        unless _tmp
          self.pos = _save6
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save7 = self.pos
      while true # sequence
        _tmp = match_string("i32")
        unless _tmp
          self.pos = _save7
          break
        end
        @result = begin;  :i32 ; end
        _tmp = true
        unless _tmp
          self.pos = _save7
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save8 = self.pos
      while true # sequence
        _tmp = match_string("i64")
        unless _tmp
          self.pos = _save8
          break
        end
        @result = begin;  :i64 ; end
        _tmp = true
        unless _tmp
          self.pos = _save8
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save9 = self.pos
      while true # sequence
        _tmp = match_string("double")
        unless _tmp
          self.pos = _save9
          break
        end
        @result = begin;  :double ; end
        _tmp = true
        unless _tmp
          self.pos = _save9
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_SimpleBaseType unless _tmp
    return _tmp
  end

  # ContainerType = SimpleContainerType
  def _ContainerType
    _tmp = apply(:_SimpleContainerType)
    set_failed_rule :_ContainerType unless _tmp
    return _tmp
  end

  # SimpleContainerType = (MapType | SetType | ListType)
  def _SimpleContainerType

    _save = self.pos
    while true # choice
      _tmp = apply(:_MapType)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_SetType)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_ListType)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_SimpleContainerType unless _tmp
    return _tmp
  end

  # MapType = "map" "<" FieldType:a osp "," osp FieldType:b ">" {map(a,b)}
  def _MapType

    _save = self.pos
    while true # sequence
      _tmp = match_string("map")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("<")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldType)
      a = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(",")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_osp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldType)
      b = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(">")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; map(a,b); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_MapType unless _tmp
    return _tmp
  end

  # SetType = "set" "<" FieldType:a ">" {set(a)}
  def _SetType

    _save = self.pos
    while true # sequence
      _tmp = match_string("set")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("<")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldType)
      a = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(">")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; set(a); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_SetType unless _tmp
    return _tmp
  end

  # ListType = "list" "<" FieldType:a ">" {list(a)}
  def _ListType

    _save = self.pos
    while true # sequence
      _tmp = match_string("list")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("<")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_FieldType)
      a = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(">")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; list(a); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ListType unless _tmp
    return _tmp
  end

  # CppType = (tok_cpp_type tok_literal | nothing)
  def _CppType

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_tok_cpp_type)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_tok_literal)
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_nothing)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_CppType unless _tmp
    return _tmp
  end

  # TypeAnnotationList = TypeAnnotationList TypeAnnotation
  def _TypeAnnotationList

    _save = self.pos
    while true # sequence
      _tmp = apply(:_TypeAnnotationList)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_TypeAnnotation)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_TypeAnnotationList unless _tmp
    return _tmp
  end

  # TypeAnnotation = tok_identifier "=" tok_literal CommaOrSemicolonOptional
  def _TypeAnnotation

    _save = self.pos
    while true # sequence
      _tmp = apply(:_tok_identifier)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("=")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_tok_literal)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_CommaOrSemicolonOptional)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_TypeAnnotation unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_intconstant] = rule_info("intconstant", "/([+-]?[0-9]+)/")
  Rules[:_hexconstant] = rule_info("hexconstant", "/(\"0x\"[0-9A-Fa-f]+)/")
  Rules[:_dubconstant] = rule_info("dubconstant", "(/([+-]?[0-9]+(\\.[0-9]+)([eE][+-]?[0-9]+)?)/ | /([+-]?[0-9]+([eE][+-]?[0-9]+))/ | /([+-]?(\\.[0-9]+)([eE][+-]?[0-9]+)?)/)")
  Rules[:_identifier] = rule_info("identifier", "/([a-zA-Z_][\\.a-zA-Z_0-9]*)/")
  Rules[:_whitespace] = rule_info("whitespace", "/([ \\t\\r\\n]*)/")
  Rules[:_st_identifier] = rule_info("st_identifier", "/([a-zA-Z-][\\.a-zA-Z_0-9-]*)/")
  Rules[:_literal_begin] = rule_info("literal_begin", "/(['\\\"])/")
  Rules[:_reserved] = rule_info("reserved", "(\"BEGIN\" | \"END\" | \"__CLASS__\" | \"__DIR__\" | \"__FILE__\" | \"__FUNCTION__\" | \"__LINE__\" | \"__METHOD__\" | \"__NAMESPACE__\" | \"abstract\" | \"alias\" | \"and\" | \"args\" | \"as\" | \"assert\" | \"begin\" | \"break\" | \"case\" | \"catch\" | \"class\" | \"clone\" | \"continue\" | \"declare\" | \"def\" | \"default\" | \"del\" | \"delete\" | \"do\" | \"dynamic\" | \"elif\" | \"else\" | \"elseif\" | \"elsif\" | \"end\" | \"enddeclare\" | \"endfor\" | \"endforeach\" | \"endif\" | \"endswitch\" | \"endwhile\" | \"ensure\" | \"except\" | \"exec\" | \"finally\" | \"float\" | \"for\" | \"foreach\" | \"function\" | \"global\" | \"goto\" | \"if\" | \"implements\" | \"import\" | \"in\" | \"inline\" | \"instanceof\" | \"interface\" | \"is\" | \"lambda\" | \"module\" | \"native\" | \"new\" | \"next\" | \"nil\" | \"not\" | \"or\" | \"pass\" | \"public\" | \"print\" | \"private\" | \"protected\" | \"public\" | \"raise\" | \"redo\" | \"rescue\" | \"retry\" | \"register\" | \"return\" | \"self\" | \"sizeof\" | \"static\" | \"super\" | \"switch\" | \"synchronized\" | \"then\" | \"this\" | \"throw\" | \"transient\" | \"try\" | \"undef\" | \"union\" | \"unless\" | \"unsigned\" | \"until\" | \"use\" | \"var\" | \"virtual\" | \"volatile\" | \"when\" | \"while\" | \"with\" | \"xor\" | \"yield\")")
  Rules[:_tok_int_constant] = rule_info("tok_int_constant", "(< intconstant > { text.to_i } | < hexconstant > { text.to_i } | \"false\" { 0 } | \"true\" { 1 })")
  Rules[:_tok_dub_constant] = rule_info("tok_dub_constant", "dubconstant:f { f.to_f }")
  Rules[:_tok_identifier] = rule_info("tok_identifier", "< identifier > {text}")
  Rules[:_tok_st_identifier] = rule_info("tok_st_identifier", "st_identifier")
  Rules[:_escapes] = rule_info("escapes", "(\"\\\\r\" { \"\\r\" } | \"\\\\n\" { \"\\n\" } | \"\\\\t\" { \"\\t\" } | \"\\\\\\\"\" { \"\\\"\" } | \"\\\\'\" { \"'\" } | \"\\\\\\\\\" { \"\\\\\" })")
  Rules[:_tok_literal] = rule_info("tok_literal", "(\"\\\"\" < (escapes | !\"\\\"\" .)* > \"\\\"\" {text} | \"'\" < (escapes | !\"'\" .)* > \"'\" {text})")
  Rules[:__hyphen_] = rule_info("-", "/[ \\t]+/")
  Rules[:_osp] = rule_info("osp", "/[ \\t]*/")
  Rules[:_bsp] = rule_info("bsp", "/[\\s]+/")
  Rules[:_obsp] = rule_info("obsp", "/[\\s]*/")
  Rules[:_root] = rule_info("root", "Program !.")
  Rules[:_Program] = rule_info("Program", "Element*:a { a }")
  Rules[:_CComment] = rule_info("CComment", "\"/*\" < (!\"*/\" .)* > \"*/\" obsp {comment(text)}")
  Rules[:_HComment] = rule_info("HComment", "\"\#\" < (!\"\\n\" .)* > bsp {comment(text)}")
  Rules[:_Comment] = rule_info("Comment", "(CComment | HComment)")
  Rules[:_CaptureDocText] = rule_info("CaptureDocText", "{}")
  Rules[:_DestroyDocText] = rule_info("DestroyDocText", "{}")
  Rules[:_HeaderList] = rule_info("HeaderList", "(HeaderList Header | Header)")
  Rules[:_Element] = rule_info("Element", "(Comment | Header bsp | Definition bsp)")
  Rules[:_Header] = rule_info("Header", "(Include | Namespace)")
  Rules[:_Namespace] = rule_info("Namespace", "(\"namespace\" - tok_identifier:l - tok_identifier:n {namespace(l,n)} | \"namespace\" - \"*\" - tok_identifier:n {namespace(nil,n)})")
  Rules[:_Include] = rule_info("Include", "\"include\" - tok_literal:f {include(f)}")
  Rules[:_DefinitionList] = rule_info("DefinitionList", "DefinitionList CaptureDocText Definition")
  Rules[:_Definition] = rule_info("Definition", "(Const | TypeDefinition | Service)")
  Rules[:_TypeDefinition] = rule_info("TypeDefinition", "(Typedef | Enum | Senum | Struct | Xception)")
  Rules[:_Typedef] = rule_info("Typedef", "\"typedef\" - FieldType tok_identifier")
  Rules[:_CommaOrSemicolonOptional] = rule_info("CommaOrSemicolonOptional", "(\",\" | \";\")? obsp")
  Rules[:_Enum] = rule_info("Enum", "\"enum\" - tok_identifier:name osp \"{\" obsp EnumDefList:vals obsp \"}\" {enum(name, vals)}")
  Rules[:_EnumDefList] = rule_info("EnumDefList", "(EnumDefList:l EnumDef:e { l + [e] } | EnumDef:e { [e] })")
  Rules[:_EnumDef] = rule_info("EnumDef", "(CaptureDocText tok_identifier \"=\" tok_int_constant CommaOrSemicolonOptional | CaptureDocText tok_identifier CommaOrSemicolonOptional)")
  Rules[:_Senum] = rule_info("Senum", "\"senum\" - tok_identifier \"{\" SenumDefList \"}\"")
  Rules[:_SenumDefList] = rule_info("SenumDefList", "(SenumDefList SenumDef | nothing)")
  Rules[:_SenumDef] = rule_info("SenumDef", "tok_literal CommaOrSemicolonOptional")
  Rules[:_Const] = rule_info("Const", "\"const\" - FieldType tok_identifier \"=\" ConstValue CommaOrSemicolonOptional")
  Rules[:_ConstValue] = rule_info("ConstValue", "(tok_int_constant:i {const_int(i)} | tok_literal:s {const_str(s)} | tok_identifier:i {const_id(i)} | ConstList | ConstMap | tok_dub_constant:d {const_dbl(d)})")
  Rules[:_ConstList] = rule_info("ConstList", "\"[\" osp ConstListContents*:l osp \"]\" {const_list(l)}")
  Rules[:_ConstListContents] = rule_info("ConstListContents", "ConstValue:i CommaOrSemicolonOptional osp {i}")
  Rules[:_ConstMap] = rule_info("ConstMap", "\"{\" osp ConstMapContents*:m osp \"}\" {const_map(m)}")
  Rules[:_ConstMapContents] = rule_info("ConstMapContents", "ConstValue:k osp \":\" osp ConstValue:v CommaOrSemicolonOptional { [k,v] }")
  Rules[:_StructHead] = rule_info("StructHead", "< (\"struct\" | \"union\") > {text}")
  Rules[:_Struct] = rule_info("Struct", "StructHead:t - tok_identifier:name - XsdAll? osp \"{\" obsp Comment? FieldList?:list obsp \"}\" {struct(t.to_sym,name,list)}")
  Rules[:_XsdAll] = rule_info("XsdAll", "\"xsd_all\"")
  Rules[:_XsdOptional] = rule_info("XsdOptional", "(\"xsd_optional\" - | nothing)")
  Rules[:_XsdNillable] = rule_info("XsdNillable", "(\"xsd_nillable\" - | nothing)")
  Rules[:_XsdAttributes] = rule_info("XsdAttributes", "(\"xsd_attrs\" - \"{\" FieldList \"}\" | nothing)")
  Rules[:_Xception] = rule_info("Xception", "\"exception\" - tok_identifier:name osp \"{\" obsp FieldList?:list obsp \"}\" {exception(name, list)}")
  Rules[:_Service] = rule_info("Service", "\"service\" - tok_identifier:name - Extends? osp \"{\" obsp FunctionList?:funcs obsp \"}\" {service(name, funcs)}")
  Rules[:_Extends] = rule_info("Extends", "\"extends\" - tok_identifier")
  Rules[:_FunctionList] = rule_info("FunctionList", "(FunctionList:l Function:f { l + [f] } | Function:f { [f] })")
  Rules[:_Function] = rule_info("Function", "CaptureDocText OneWay? FunctionType:rt - tok_identifier:name osp \"(\" FieldList?:args \")\" Throws? CommaOrSemicolonOptional {function(name, rt, args)}")
  Rules[:_OneWay] = rule_info("OneWay", "(\"oneway\" | \"async\") -")
  Rules[:_Throws] = rule_info("Throws", "\"throws\" - \"(\" FieldList \")\"")
  Rules[:_FieldList] = rule_info("FieldList", "(FieldList:l Field:f { l + [f] } | Field:f { [f] })")
  Rules[:_Field] = rule_info("Field", "CaptureDocText FieldIdentifier?:i osp FieldRequiredness?:req osp FieldType:t osp tok_identifier:n osp FieldValue?:val CommaOrSemicolonOptional {field(i,t,n,val,req)}")
  Rules[:_FieldIdentifier] = rule_info("FieldIdentifier", "tok_int_constant:n \":\" {n}")
  Rules[:_FieldRequiredness] = rule_info("FieldRequiredness", "< (\"required\" | \"optional\") > { [text] }")
  Rules[:_FieldValue] = rule_info("FieldValue", "\"=\" osp ConstValue:e {e}")
  Rules[:_FunctionType] = rule_info("FunctionType", "(FieldType | \"void\")")
  Rules[:_FieldType] = rule_info("FieldType", "(ContainerType | tok_identifier:n {n})")
  Rules[:_BaseType] = rule_info("BaseType", "SimpleBaseType:t TypeAnnotations {t}")
  Rules[:_SimpleBaseType] = rule_info("SimpleBaseType", "(\"string\" { :string } | \"binary\" { :binary } | \"slist\" { :slist } | \"bool\" { :bool } | \"byte\" { :byte } | \"i16\" { :i16 } | \"i32\" { :i32 } | \"i64\" { :i64 } | \"double\" { :double })")
  Rules[:_ContainerType] = rule_info("ContainerType", "SimpleContainerType")
  Rules[:_SimpleContainerType] = rule_info("SimpleContainerType", "(MapType | SetType | ListType)")
  Rules[:_MapType] = rule_info("MapType", "\"map\" \"<\" FieldType:a osp \",\" osp FieldType:b \">\" {map(a,b)}")
  Rules[:_SetType] = rule_info("SetType", "\"set\" \"<\" FieldType:a \">\" {set(a)}")
  Rules[:_ListType] = rule_info("ListType", "\"list\" \"<\" FieldType:a \">\" {list(a)}")
  Rules[:_CppType] = rule_info("CppType", "(tok_cpp_type tok_literal | nothing)")
  Rules[:_TypeAnnotationList] = rule_info("TypeAnnotationList", "TypeAnnotationList TypeAnnotation")
  Rules[:_TypeAnnotation] = rule_info("TypeAnnotation", "tok_identifier \"=\" tok_literal CommaOrSemicolonOptional")
  # :startdoc:
end
