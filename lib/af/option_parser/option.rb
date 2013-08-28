module ::Af::OptionParser
  class Option < InstanceVariableSetter
    FACTORY_SETTABLES = [ :option_type, :requirements, :short_name, :argument_note, :note,
                          :environment_variable, :default_value, 
                          :option_group_name, :choices ]
    attr_accessor *FACTORY_SETTABLES
    attr_accessor :long_name

    def initialize(long_name, parameters = {})
      super(parameters)
      @long_name = long_name
    end

    def set_instance_variables(parameters = {})
      super(parameters, FACTORY_SETTABLES)
    end

    def merge(that_option)
      super(that_option, FACTORY_SETTABLES)
    end

    def error(text)
      puts "ERROR: #{self.long_name}: #{text} (--? for help)"
      exit 1
    end
  end
end
