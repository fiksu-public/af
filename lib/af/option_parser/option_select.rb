module ::Af::OptionParser
  class OptionSelect < InstanceVariableSetter
    FACTORY_SETTABLES = [
                          :action,
                          :targets,
                          :error_message
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
    # Available actions: one_of, none_or_one_of, one_or_more_of
    #
    # If an invalidation occurs, an OptionSelectError is raised
    # with a specific message.
    def validate
      # If an option_select is used, an array of options must be given
      if targets.blank?
        raise OptionSelectError.new("An array of options must be specified")
      end

      # Populate the options_set array with all instantiated class/instance variables
      options_set = []
      targets.each do |target|
        if target_container.try(target.to_sym).present?
          options_set << target
        end
      end

      if action == :one_of && options_set.size != 1
        raise OptionSelectError.new("You must specify only one of these options: --#{targets.join(', --')}")
      elsif action == :none_or_one_of && options_set.size > 1
        raise OptionSelectError.new("You must specify no more than one of these options: --#{targets.join(', --')}")
      elsif action == :one_or_more_of && options_set.size < 1
        raise OptionSelectError.new("You must specify at least one of these options: --#{targets.join(', --')}")
      end
    end

  end
end
