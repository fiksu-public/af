module ::Af::OptionParser
  class OptionCheck < InstanceVariableSetter
    ACTIONS = [
               ONE_OF = 0,
               NONE_OR_ONE = 1,
               ONE_OR_MORE_OF = 2,
               EXCLUDES = 3,
               REQUIRES = 4,
               CHECK = 5
              ]
    FACTORY_SETTABLES = [ :action, :targets, :error_message, :block ]
    attr_accessor *FACTORY_SETTABLES
    attr_accessor :var_name

    def initialize(var_name, parameters = {})
      super(parameters)
      @var_name = var_name
    end

    def set_instance_variables(parameters = {})
      super(parameters, FACTORY_SETTABLES)
    end

    def merge(that_option)
      super(that_option, FACTORY_SETTABLES)
    end
  end
end
