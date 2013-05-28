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
#    logger.info "foobar: #{Foo.foobar}"
    logger.info "WORK STARTED: #{@word}"
    logger.info @words.inspect
    logger.info "NUMBERS: #{@numbers.inspect}"

    AfSideComponent.new.do_something

    logger.info "WORK COMPLETED: #{@word}"
  end
end

