class AfSideComponent
  include Af::Application::Component

  opt_group :side_component_stuff, "options associated with this side component" do
    opt :a_side_component_option, :default => "foo"
  end

  opt :basic_option_from_component, "this is a switch from the side component, in the basic (default) group"

  create_proxy_logger :foo

  def do_something
    foo_logger.info "doing something @@a_side_component_option='#{@@a_side_component_option}'"
    foo_logger.info "did something @@basic_option_from_component=#{@@basic_option_from_component.inspect}"
  end
end
