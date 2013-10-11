module ::Af::OptionParser
  class OptionCheck < InstanceVariableSetter
    FACTORY_SETTABLES = [
                          :action,
                          :targets,
                          :error_message,
                          :block
                        ]

    attr_accessor *FACTORY_SETTABLES
    attr_accessor :var_name

    def initialize(var_name, parameters = {})
      super(parameters)
      @var_name = var_name
    end

    #-------------------------
    # *** Instance Methods ***
    #+++++++++++++++++++++++++

    def set_instance_variables(parameters = {})
      super(parameters, FACTORY_SETTABLES)
    end

    def merge(that_option)
      super(that_option, FACTORY_SETTABLES)
    end

    # This methods validates the selected options based
    # on the chosen action.
    #
    # Available actions: requires, excludes
    #
    # If an invalidation occurs, an OptionCheckError is raised
    # with a specific message.
    def validate
      # If an option_check is used, the target_variable must be instantiated
      if target_container.try(target_variable.to_sym).blank?
        raise OptionCheckError.new("Option --#{target_variable} must be specified")
      end

      # If an option_check is used, an array of options must be given
      if targets.empty?
        raise OptionCheckError.new("An array of #{action.to_s[0..-2]}d options must be specified")
      end

      if action == :requires
        # Each target option must be specified
        targets.each do |target|
          if target_container.try(target.to_sym).blank?
            raise OptionCheckError.new("You must specify these options: --#{targets.join(', --')}")
          end
        end
      elsif action == :excludes
        # None of the target options can be specified
        targets.each do |target|
          if target_container.try(target.to_sym).present?
            raise OptionCheckError.new("You cannot specify these options: --#{targets.join(', --')}")
          end
        end
      end
    end

  end
end
