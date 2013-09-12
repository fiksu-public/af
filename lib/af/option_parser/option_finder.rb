module ::Af::OptionParser
  class OptionFinder

    def initialize(class_path)
      @class_path = class_path
      @all_options = {}
      @all_option_groups = {}
      @all_option_checks = {}
      @all_option_selects = {}

      # class_path:
      #  Class: include class and all its ancestors options
      @class_path.each do |klass|
        klass.ancestors.reverse.each do |ancestor|
          option_store = OptionStore.find(ancestor)
          if option_store
            options = option_store.options
            if options.present?
              options.each do |long_name, option|
                merged_option = @all_options[long_name] ||= Option.new(long_name)
                merged_option.set_instance_variables(option)
              end
            end

            option_groups = option_store.option_groups
            if option_groups.present?
              option_groups.each do |name, option_group|
                merged_option_group = @all_option_groups[name] ||= OptionGroup.new(name)
                merged_option_group.set_instance_variables(option_group)
              end
            end

            option_checks = option_store.option_checks
            if option_checks.present?
              option_checks.each do |name, option_check|
                merged_option_check = @all_option_checks[name] ||= OptionCheck.new(name)
                merged_option_check.set_instance_variables(option_check)
              end
            end

            option_selects = option_store.option_selects
            if option_selects.present?
              option_selects.each do |name, option_select|
                merged_option_select = @all_option_selects[name] ||= OptionSelect.new(name)
                merged_option_select.set_instance_variables(option_select)
              end
            end
          end
        end
      end
    end

    #-------------------------
    # *** Instance Methods ***
    #+++++++++++++++++++++++++

    def all_options
      return @all_options.values
    end

    def all_option_groups
      return @all_option_groups.values
    end

    def all_option_checks
      return @all_option_checks.values
    end

    def all_option_selects
      return @all_option_selects.values
    end

    def all_options_by_long_name
      return @all_options
    end

    def all_option_checks_by_var_name
      return @all_option_checks
    end

    def find_option(long_name)
      return all_options_by_long_name[long_name]
    end

    def find_option_check(var_name)
      return all_option_checks_by_var_name[var_name]
    end

  end
end
