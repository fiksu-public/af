module ::Af::OptionParser
  class OptionType
    attr_reader :name, :sort_name, :argument_note, :evaluate_method, :handler_method

    @@types = []

    def self.types
      return @@types
    end

    def initialize(name, sort_name, argument_note, evaluate_method, handler_method)
      @name = name
      @sort_name = sort_name
      @argument_note = argument_note
      @evaluate_method = evaluate_method
      @handler_method = handler_method
      @@types << self
    end

    def evaluate_argument(argument)
      if @evaluate_method.is_a? Symbol
        return argument.send(@evaluate_method)
      end
      return @evaluate_method.call(argument)
    end

    def handle?(value)
      if @handle_method.is_a? Class
        return value.is_a? @handle_method
      end
      return value.call(@handler_method)
    end

    def self.find_by_value(value)
      return types.find{|t| t.handle?(value)}
    end

    def self.find_by_short_name(short_name)
      return types.find{|t| t.short_name == short_name}
    end
  end

  new OptionType(:Int, :int, "INTEGER", :to_i, Fixnum)
  new OptionType(:Integer, :integer, "INTEGER", :to_i, Fixnum)
  new OptionType(:Float, :float, "NUMBER", :to_f, Float)
  new OptionType(:Number, :number, "NUMBER", :to_f, Float)
  new OptionType(:String, :string, "STRING", :to_s, String)
  new OptionType(:Uri, :uri, "URI", lambda {|argument, option_parser| return URI.parse(argument) }, URI::HTTP)
  new OptionType(:Date, :date, "DATE", lambda {|argument, option_parser| return Time.zone.parse(argument).to_date }, Date)
  new OptionType(:Time, :time, "TIME", lambda {|argument, option_parser| return Time.zone.parse(argument) }, Time)
  new OptionType(:DateTime, :time, "TIME", lambda {|argument, option_parser| return Time.zone.parse(argument) }, DateTime)
  new OptionType(:Choice, :choice, "CHOICE", lambda {|argument, option_parser|
                   choice = argument.to_sym
                   choices = option_parser.choices
                   unless choices.blank?
                     unless choices.include? choice
                       raise BadChoice.new("invalid choice '#{choice}' not in list of choices: #{choices.map(&:to_s).join(', ')}")
                     end
                   end
                   return choice
                 }, Symbol)
  new OptionType(:Hash, :hash, "K1=V1,K2=V2,K3=V3...", lambda {|argument, option_parser| return Hash[argument.split(',').map{|ai| ai.split('=')}] }, Hash)
  new OptionType(:Ints, :ints, "INT1,INT2,INT3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_i) }, lambda {|value| return value.class == Array && value.first.class == Fixnum })
  new OptionType(:Integers, :ints, "INT1,INT2,INT3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_i) }, lambda {|value| return value.class == Array && value.first.class == Fixnum })
  new OptionType(:Floats, :floats, "NUM1,NUM2,NUM3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_f) }, lambda {|value| return value.class == Array && value.first.class == Float })
  new OptionType(:Numbers, :numbers, "NUM1,NUM2,NUM3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_f) }, lambda {|value| return value.class == Array && value.first.class == Float })
  new OptionType(:Strings, :strings, "STR1,STR2,STR3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_s) }, lambda {|value| return value.class == Array && value.first.class == String })
  new OptionType(:Uris, :uris, "URL1,URL2,URL3...", lambda {|argument, option_parser| return argument.split(',').map{|a| URI.parse(a)} }, lambda {|value| return value.class == Array && value.first.class == URI::HTTP })
  new OptionType(:Dates, :dates, "DATE1,DATE2,DATE3...", lambda {|argument, option_parser| return argument.split(',').map{|a| Time.zone.parse(a).to_date} }, lambda {|value| return value.class == Array && value.first.class == Date })
  new OptionType(:Times, :times, "TIME1,TIME2,TIME3...", lambda {|argument, option_parser| return argument.split(',').map{|a| Time.zone.parse(a) } }, lambda {|value| return value.class == Array && value.first.class == Time })
  new OptionType(:DateTimes, :times, "TIME1,TIME2,TIME3...", lambda {|argument, option_parser| return argument.split(',').map{|a| Time.zone.parse(a) } }, lambda {|value| return value.class == Array && value.first.class == DateTime })
  new OptionType(:Choices, :times, "CHOICE1,CHOICE2,CHOICE3...", lambda {|argument, option_parser|
                   choice_list = argument.split(',').map(&:to_sym)
                   choices = option_parser.choices
                   unless choices.blank?
                     choice_list.each do |choice|
                       unless choices.include? choice
                         raise BadChoice.new("invalid choice '#{choice}' not in list of choices: #{choices.map(&:to_s).join(', ')}")
                       end
                     end
                   end
                   return choice_list
                 }, lambda {|value| return value.class == Array && value.first.class == Symbol })
end
