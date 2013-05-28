module ::Af::OptionParser
  class Option
    FACTORY_SETTABLES = [ :option_type, :requirements, :short_name, :argument_note, :note,
                          :environment_variable, :default_value, :evaluation_method,
                          :option_group_name, :hidden, :choices, :value_to_set_target_variable,
                          :do_not_create_accessor, :target_variable, :target_container, :disabled ]
    attr_accessor *FACTORY_SETTABLES
    attr_accessor :long_name

    # ACCESSORS

    def target_container
      if @target_container == :af_application
        @target_container = ::Af::Application.singleton
      end
      return @target_container
    end

    def target_class_variable
      return "@@#{target_variable}"
    end

    def target_instance_variable
      return "@#{target_variable}"
    end

    def has_value_to_set_target_variable?
      return @has_value_to_set_target_variable || false
    end

    def initialize(long_name, parameters = {})
      @long_name = long_name
      set_instance_variables(parameters)
      @target_container ||= :af_application
    end

    def evaluate_and_set_target(argument)
      value = evaluate(argument)
      set_target_variable(value)
    end

    def evaluate(argument)
      if has_value_to_set_target_variable?
        argument = @value_to_set_target_variable
      else
        if @requirements == ::Af::OptionParser::GetOptions::NO_ARGUMENT
          argument = true
        end
      end
      evaluator = @evaluation_method ||
        @option_type ||
        OptionType.find_by_value(argument) ||
        OptionType.find_by_short_name(:switch)
      if evaluator.nil?
        raise UndeterminedArgumentTypeError.new(@long_name)
      elsif evaluator.is_a? Proc
        return evaluator.call(argument, self)
      else
        return evaluator.evaluate_argument(argument, self)
      end
    end

    def instantiate_target_variable
      if target_container.present? && target_variable.present?
        set_target_variable(@default_value)
        unless @do_not_create_accessor
          if target_container.is_a? Class
            target_container.class_eval "def self.#{target_variable}; return #{target_class_variable}; end"
            target_container.class_eval "def self.#{target_variable}=(value); return #{target_class_variable} = value; end"
          else
            target_container.class.class_eval "attr_accessor :#{target_variable}"
          end
        end
      end
    end

    def set_target_variable(value)
      if target_container.present? && target_variable.present?
        if target_container.is_a? Class
          # this is a Class -- set @@foo
          target_container.class_variable_set(target_class_variable, value)
        else
          # this is an instance -- set @foo
          target_container.instance_variable_set(target_instance_variable, value)
        end
      end
    end

    def set_instance_variables(parameters = {})
      parameters.select do |name,value|
        FACTORY_SETTABLES.include? name
      end.each do |name,value|
        instance_variable_set("@#{name}", value)
      end
      if parameters[:value_to_set_target_variable]
        @has_value_to_set_target_variable = true
      end
    end

    def merge(that_option)
      FACTORY_SETTABLES.each do |name|
        if that_option.instance_variable_defined?("@#{name}")
          if name == :target_container && self.instance_variable_defined?("@target_container") && that_option.send(name) == ::Af::Application.singleton
            # such a hack -- ignore target_container if set a second time because its default is not null nil
            next
          end
          self.send("#{name}=", that_option.send(name))
        end
      end
    end

    def self.factory(long_name, containing_class, factory_hash = {})
      option = OptionStore.factory(containing_class).get_option(long_name)
      option.set_instance_variables(factory_hash)
      return option
    end
  end
end
