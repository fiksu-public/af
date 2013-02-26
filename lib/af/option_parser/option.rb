module ::Af::OptionParser
  class Option
    include ::Af::Application::Component

    attr_accessor :option_type, :requirements, :short_name, :long_name, :argument_note, :note, :environment_variable
    attr_accessor :default_value, :set, :evaluation_method, :option_group_name, :hidden, :choices
    attr_accessor :value_to_set_target_variable, :do_not_create_accessor
    attr_writer :target_variable, :target_container

    @@options = {}

    def self.all_options
      return @@options
    end

    def self.all_option_types
      return @@option_types ||= options.map{|o| o.option_type}.uniq
    end

    def initialize(long_name, short_name = nil, option_type = nil, requirements = nil, argument_note = nil,
                   note = nil, environment_variable = nil, default_value = nil, target_variable = nil,
                   value_to_set_target_variable = nil, evaluation_method = nil, option_group_name = nil,
                   hidden = nil, choices = nil, do_not_create_accessor = nil, target_container = nil)
      @long_name = long_name
      @short_name = short_name
      @option_type = option_type
      @requirements = requirements
      @argument_note = argument_note
      @note = note
      @environment_variable = environment_variable
      @default_value = default_value
      @target_variable = target_variable
      @value_to_set_target_variable = value_to_set_target_variable
      @evaluation_method = evaluation_method
      @option_group_name = option_group_name
      @hidden = hidden
      @choices = choices
      @do_not_create_accessor = do_not_create_accessor
      @target_container = target_container || af_application
      @@options[long_name] = self
    end

    def evaluate_and_set_target(argument)
      value = evaluate(argument)
      set_target_value(value)
    end

    def evaluate(argument)
      if @value_to_set_target_variable.present?
        argument = @value_to_set_target_variable
      else
        if @requirements == ::Af::OptionParser::GetOptions::NO_ARGUMENT
          argument = true
        end
      end
      evaluator = @option_type ||
        OptionType.find_by_value(argument) ||
        OptionType.find_by_short_name(:string)
      raise UndeterminedArgumentTypeError.new(@long_name) unless evaluator
      return evaluator.evaluate_argument(argument, self)
    end

    def instantiate_target_variable
      if @target_container.present?
        if @target_variable.present?
          if @default_value.present? || !@target_container.instance_variable_defined?("@#{@target_variable}")
            @target_container.instance_variable_set("@#{@target_variable}", @default_value)
          end
          unless @do_not_create_accessor
            @target_container.class.class_eval "attr_accessor :#{@target_variable}"
          end
        end
      end
    end

    def set_target_variable(value)
      if @target_container
        @target_container.instance_variable_set("@#{@target_variable}", value)
      end
    end

    def target_variable
      unless @target_variable
        @target_variable = @long_name[2..-1].gsub(/-/, '_').gsub(/[^0-9a-zA-Z]/, '_')
      end
      return @target_variable
    end

    def self.find(long_name)
      return all_options[long_name]
    end

    def self.factory(long_name, short_name = nil, option_type = nil, requirements = nil, argument_note = nil,
                     note = nil, environment_variable = nil, default_value = nil, target_variable = nil,
                     value_to_set_target_variable = nil, evaluation_method = nil, option_group_name = nil,
                     hidden = nil, choices = nil, do_not_create_accessor = nil, target_container = nil)
      option = find(long_name) || new(long_name)
      option.option_type = option_type if option_type
      option.requirements = requirements if requirements
      option.short_name = short_name if short_name
      option.argument_note = argument_note if argument_note
      option.note = note if note
      option.environment_variable = environment_variable if environment_variable
      option.default_value = default_value if default_value.present?
      option.target_variable = target_variable if target_variable
      option.value_to_set_target_variable = value_to_set_target_variable if value_to_set_target_variable.present?
      option.evaluation_method = evaluation_method if evaluation_method
      option.option_group_name = option_group_name if option_group_name
      option.hidden = hidden if hidden.present?
      option.choices = choices if choices
      option.do_not_create_accessor = do_not_create_accessor if do_not_create_accessor.present?
      option.target_container = target_container if target_container.present?
      return option
    end
  end
end
