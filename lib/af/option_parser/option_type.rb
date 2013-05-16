module ::Af::OptionParser
  class OptionType
    attr_reader :name, :short_name, :argument_note, :evaluate_method, :handler_method

    @@types = []

    def self.types
      return @@types
    end

    def self.valid_option_type_names
      return types.map(&:short_name)
    end

    def initialize(name, short_name, argument_note, evaluate_method, handler_method)
      @name = name
      @short_name = short_name
      @argument_note = argument_note
      @evaluate_method = evaluate_method
      @handler_method = handler_method
      @@types << self
    end

    def evaluate_argument(argument, option)
      if @evaluate_method.is_a? Symbol
        return argument.send(@evaluate_method)
      end
      return @evaluate_method.call(argument, option)
    end

    def handle?(value)
      if @handler_method.is_a? Class
        return value.is_a? @handler_method
      end
      return @handler_method.call(value)
    end

    def self.find_by_value(value)
      return types.find{|t| t.handle?(value)}
    end

    def self.find_by_short_name(short_name)
      return types.find{|t| t.short_name == short_name}
    end
  end
end
