# Af - an application framework

gem 'fiksu-af'

This application framework supports:

* an Application class with supporting infrastruction
* command line options integrated into instance (and class) variables
* logging via log4r with support for papertrail
* postgres advisory locking via pg_advisor_locker gem
* postgres database connection updates via pg_application_name gem
* threads and message passing
* application components adding loggers and command line options

## Application class

The class ::Af::Application provides a basic interface to the start-up
and management of Ruby on Rails scripts.

A simple example of an application which logs its startup and exits
is:

```
class MyApplication < ::Af::Application
  opt :word, "the word", :short => :w, :default => "bird"

  def work
    logger.info "Started up: #{@word} is the word"
    exit 0
  end
end
```

Class-method "opt" specifies command line parameter(s) whose arguments
are stored in instance variables.  MyApplication specifies a single
parameter "--word" with a short alias "-w" that accepts a string
argument (whose default is "bird", so we know it should be a string).
The parameters value will be stored in class instance variable: @word.
More information on command line option glue is provided in the
Command Line Options section.

The method "logger" is available to ::Af::Application to create and
fetch log4r loggers.  In this case, we use the basic application
logger (named "MyApplication") and logs an INFO level message.  More
information on the glue ::Af::Application provides with Log4r is
in the logging section below.

This application would be run from the command line as:

```
$ script/rails runner MyApplication.run --word grease
```

The class method #run provides start-up glue for applications, parsing
command line options, environment variables and configuration files.
The instance method #work is where application codes start their work.

## Command Line Options

a more interesting example of options from multiple classes

```
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
```

```
class AfScriptWithOptions < ::Af::Application
  opt_group :singles, "parameters whose types are a single value" do
    opt :a_switch, "a switch"
    opt :an_int, "an integer of some sort", :default => 1
    opt :a_float, "a float of some sort whose default is PI", :default => 3.14
    opt :a_string, "a string of some sort", :type => :string
    opt :a_uri, "some uri", :type => :uri
    opt :a_date, "a date", :type => :date
    opt :a_time, "a time", :type => :time
    opt :a_datetime, "a datetime", :type => :datetime
    opt :a_choice, "a choice", :argument_note => "COLOR", :choices => [:red, :blue, :green, :yellow, :white, :black, :orange]
  end

  # there is already an advanced option group -- it is set to hidden by default
  opt_group :advanced, "advanced parameters", :hidden => false do
    opt :a_small_integer, "another integer", :default => 10, :argument_note => "[1 >= INTEGER <= 10]" do |argument,option|
      argument = argument.to_i
      if (argument < 1 || argument > 10)
        opt_error "ERROR: #{option.long_name}: value must be between 1 and 10 (inclusive)"
      end
      argument
    end
    opt :a_constrained_number, "a number which is not an integer", :requirement => :required, :argument_note => "NON-INTEGER" do |argument,option|
      i_argument = argument.to_i
      f_argument = argument.to_f
      if (i_argument == f_argument)
        opt_error "ERROR: #{option.long_name}: value must not be an integer"
      end
      f_argument
    end
  end

  opt_group :collections, "parameters whose types are collections" do
    opt :a_hash, "a key value pair", :type => :hash
    opt :some_ints, "a list of integer", :type => :ints
    opt :some_integers, "a list of integer", :type => :integers
    opt :some_floats, "a list of floats", :type => :floats
    opt :some_numbers, "a list of numbers", :type => :numbers
    opt :some_strings, "a list of strings", :type => :strings
    opt :some_uris, "a list of uris", :type => :uris
    opt :some_dates, "a list of dates", :type => :dates
    opt :some_times, "a list of times", :type => :times
    opt :some_datetimes, "a list of datetimes", :type => :datetimes
    opt :some_choices, "a list of choices", :choices => [:foo, :bar, :baz, :beltch]
  end

  opt_group :blank, "a blank group that won't be seen"

  opt :word, "the word to print", :default => :foo, :choices => [:foo, :bar, :baz, :beltch]
  opt :words, "the words to print", :default => [:foo], :choices => [:foo, :bar, :baz, :beltch]
  opt :numbers, "the number lists", :default => [1,2,3]
  opt :switcher, "this is a switch"

  def af_opt_class_path
    [AfSideComponent] + super
  end

  def logger
    super('Process::T')
  end

  def work
    logger.info "switcher: #{switcher.inspect}"
    logger.info "WORK STARTED: #{@word}"
    logger.info @words.inspect
    logger.info "NUMBERS: #{@numbers.inspect}"

    AfSideComponent.new.do_something

    logger.info "WORK COMPLETED: #{@word}"
  end
end

```

## Logging with Log4r

Some changes to Log4r:

* root loggers are no longer null loggers -- you can add outputters to them
* the global logger is used to set a global log level (root is no longer used for this)
* yaml configurator has been updated to handle new root logger semantics
* yaml configurator has been updated to accept a set of files AND sections (default section: log4r_config)

What this really means is that you can set up one outputter in the root
logger to manage the default logging behavior.

## Thread Pool

*TODO*

## TCP Message Passing

*TODO*
