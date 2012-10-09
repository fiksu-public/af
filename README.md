# Af - an application framework

This application framework supports:

* Application class with supporting infrastruction
* command line options integrated into instance variables
* logging via log4r with support for papertrail
* postgres advisory locking via pg_advisor_locker gem
* postgres database connection updates via pg_application_name gem
* threads and message passing

## Application class

The class ::Af::Application provides a basic interface to the start-up
and management of Ruby on Rails scripts.

A simple example of an application which logs its startup and exits
is:

<code>
  class MyApplication < ::Af::Application
    opt :word, "the word", :short => :w, :default => "bird"

    def work
      logger.info "Started up: #{@word} is the word"
      exit 0
    end
  end
</code>

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

<code>
  $ script/rails runner MyApplication.run --word grease
</code>

The class method #run provides start-up glue for applications, parsing
command line options, environment variables and configuration files.
The instance method #work is where application codes start their work.

## Command Line Options

## Logging with Log4r

Some changes to Log4r:

* root loggers are no longer null loggers -- you can add outputters to them
* the global logger is used to set a global log level (root is no longer used for this)
* yaml configurator has been updated to handle new root logger semantics
* yaml configurator has been updated to accept a set of files AND sections (default section: log4r_config)

What this really means is that you can set up one outputter in the root
logger to manage the default logging behavior.
