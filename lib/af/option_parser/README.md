=== OptionParser

Things still to do:

provide proxy access so that non-Application classes can add options
options will be class variables

provide ability to specify option dependancies
--foo requires --bar and --baz
--beltch is always required

needs: opt_usage -- to set the usage string

needs: opt_banner -- to set the banner

needs: opt_env -- set an environment variable without a switch

replace Getoptlong

opt_group :foogroupname do
  opt :foo
  opt :bar
end

handle switches better:
 --foo --no-foo or something

fix the factories so they don't look like C code

opt_group :debug_server, {:title => "the debug server", :container => ::Logical::DebugServer} do
  opt :foo
end
