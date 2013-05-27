module ::Af::OptionParser
  class OptionFinder
    def initialize(class_path)
      @class_path = class_path
      @all_options = {}
      @all_option_groups = {}
      # class_path:
      #  Class: include class and all its ancestors options
      @class_path.each do |klass|
        klass.ancestors.reverse.each do |ancestor|
          option_store = OptionStore.find(ancestor)
          if option_store
            options = option_store.options
            if options
              options.each do |long_name,option|
                merged_option = @all_options[long_name] ||= Option.new(long_name)
                merged_option.merge(option)
              end
            end

            option_groups = option_store.option_groups
            if option_groups
              option_groups.each do |name,option_group|
                merged_option_group = @all_option_groups[name] ||= OptionGroup.new(name)
                merged_option_group.merge(option_group)
              end
            end
          end
        end
      end
    end

    def all_options
      return @all_options.values
    end

    def all_option_groups
      return @all_option_groups.values
    end

    def all_options_by_long_name
      return @all_options
    end

    def find_option(long_name)
      return all_options_by_long_name[long_name]
    end
  end
end
