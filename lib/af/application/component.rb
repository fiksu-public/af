module Af
  class Application
    # Proxy's are used by dependant classes to reach back to the Application frame for
    # some functionality.
    #
    # consider a model that wishes to use the logging functionality of Af:
    #
    #    class Foo < ActiveRecord::Base
    #      include ::Af::Application::SafeProxy
    #
    #      after_create :do_something_after_create
    #
    #      def foo_logger
    #        return af_logger(self.class.name)
    #      end
    #
    #      private
    #      def do_something_after_create
    #        foo_logger.info "created: #{self.inspect}"
    #      end
    #    end
    #
    # The difference between Proxy and SafeProxy is simply that
    # SafeProxy can be used in classes that may not be in an Af::Application
    # run (ie, models that are shared with a Rails web app where Af::Application
    # is never instantiated)
    #
    module Component
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def create_proxy_logger(prefix = "", logger_name = self.class.name)
          if !prefix.blank? && prefix[-1..-1] != '_'
            prefix = "#{prefix}_"
          end
          method_name = "#{prefix}logger"
          class_eval "def #{method_name}; return af_logger('#{logger_name}'); end"
        end

        def opt(long_name = nil, *extra_stuff, &b)
          return ::Af::Application.opt(long_name, *extra_stuff, &b)
        end

        def opt_group(group_name, *extra_stuff, &b)
          if extra_stuff[-1].is_a? Hash
            more_extra_stuff = extra_stuff[-1].merge({:target_container => self, :disabled => true})
          else
            more_extra_stuff = extra_stuff + [{:target_container => self, :disabled => true}]
          end
          return ::Af::Application.opt_group(group_name, *more_extra_stuff, &b)
        end
      end

      def af_logger(logger_name = (af_name || "Unknown"))
        return ::Af::Application.singleton.logger(logger_name)
      end

      def af_name
        return ::Af::Application.singleton.af_name
      end

      def af_application
        return ::Af::Application.singleton.af_name
      end
    end
  end
end
