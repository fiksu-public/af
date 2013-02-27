module ::Af::OptionParser
  class Option
    include ::Af::Application::Component

    FACTORY_SETTABLES = [ :option_type, :requirements, :short_name, :argument_note, :note,
                          :environment_variable, :default_value, :evaluation_method,
                          :option_group_name, :hidden, :choices, :value_to_set_target_variable,
                          :do_not_create_accessor, :target_variable, :target_container ]
    attr_accessor *FACTORY_SETTABLES
    attr_accessor :long_name

    @@options = {}

    def self.all_options
      return @@options
    end

    def self.all_option_types
      return @@option_types ||= options.map{|o| o.option_type}.uniq
    end

    # ACCESSORS

    def target_container
      if @target_container == :af_application
        @target_container = ::Af::Application.singleton
      end
      return @target_container
    end

    def target_variable
      unless @target_variable
        @target_variable = @long_name[2..-1].gsub(/-/, '_').gsub(/[^0-9a-zA-Z]/, '_')
      end
      return @target_variable
    end

    def initialize(long_name, parameters = {})
      @long_name = long_name
      set_instance_variables(parameters)
      @target_container ||= :af_application
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
      evaluator = @evaluation_method ||
        @option_type ||
        OptionType.find_by_value(argument) ||
        OptionType.find_by_short_name(:string)
      raise UndeterminedArgumentTypeError.new(@long_name) unless evaluator
      return evaluator.evaluate_argument(argument, self)
    end

    def instantiate_target_variable
      if target_container.present?
        if target_variable.present?
          target_container.instance_variable_set("@#{target_variable}", @default_value)
          unless @do_not_create_accessor
            target_container.class.class_eval "attr_accessor :#{target_variable}"
          end
        end
      end
    end

    def set_target_variable(value)
      if target_container
        target_container.instance_variable_set("@#{target_variable}", value)
      end
    end

    def self.find(long_name)
      return all_options[long_name]
    end

    def set_instance_variables(parameters = {})
      parameters.select do |name,value|
        FACTORY_SETTABLES.include? name
      end.each do |name,value|
        instance_variable_set("@{name}", value)
      end
    end

    def self.factory(long_name, factory_hash = {})
      option = find(long_name) || new(long_name)
      option.set_instance_variables(factory_hash)
      return option
    end
  end
end
