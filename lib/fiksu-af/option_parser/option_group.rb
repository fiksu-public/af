module ::Af::OptionParser
  class OptionGroup
    FACTORY_SETTABLES = [:title,
                         :priority,
                         :description,
                         :hidden,
                         :disabled]
    attr_accessor *FACTORY_SETTABLES
    attr_accessor :group_name

    def initialize(group_name, parameters = {})
      @group_name = group_name
      set_instance_variables(parameters)
    end

    #-------------------------
    # *** Instance Methods ***
    #+++++++++++++++++++++++++

    def set_instance_variables(parameters = {})
      parameters.select do |name,value|
        FACTORY_SETTABLES.include? name
      end.each do |name,value|
        instance_variable_set("@#{name}", value)
      end
    end

    def merge(that_option_group)
      FACTORY_SETTABLES.each do |name|
        if that_option_group.instance_variable_defined?("@#{name}")
          self.send("#{name}=", that_option_group.send(name))
        end
      end
    end

  end
end
