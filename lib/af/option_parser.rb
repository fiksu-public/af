require 'af/option_parser/columnizer.rb'
require 'af/option_parser/dsl.rb'
require 'af/option_parser/get_options.rb'
require 'af/option_parser/helper.rb'
require 'af/option_parser/interface.rb'
require 'af/option_parser/option.rb'
require 'af/option_parser/option_group.rb'
require 'af/option_parser/option_type.rb'
require 'af/option_parser/option_store.rb'
require 'af/option_parser/option_finder.rb'

module Af::OptionParser
  include Interface

  class Error < ArgumentError; end
  class MisconfiguredOptionError < Error; end
  class BadChoiceError < Error; end
  class UndeterminedArgumentTypeError < Error; end

  def self.included(base)
    add_option_types
    base.extend(Dsl)
  end

  def self.add_option_types
    OptionType.new(:Switch, :switch, "", lambda {|argument,option|
                     if ["t", "true", "yes", "on"].include?(argument.to_s.downcase)
                       return true
                     elsif ["f", "false", "no", "off"].include?(argument.to_s.downcase)
                       return false
                     else
                       if option.default_value == nil
                         return true
                       else
                         return !option.default_value
                       end
                     end
                   }, lambda{|value| return (value.is_a?(TrueClass) || value.is_a?(FalseClass))})
    OptionType.new(:Int, :int, "INTEGER", :to_i, Fixnum)
    OptionType.new(:Integer, :integer, "INTEGER", :to_i, Fixnum)
    OptionType.new(:Float, :float, "NUMBER", :to_f, Float)
    OptionType.new(:Number, :number, "NUMBER", :to_f, Float)
    OptionType.new(:String, :string, "STRING", :to_s, String)
    OptionType.new(:Uri, :uri, "URI", lambda {|argument, option_parser| return URI.parse(argument) }, URI::HTTP)
    OptionType.new(:Date, :date, "DATE", lambda {|argument, option_parser| return Time.zone.parse(argument).to_date }, Date)
    OptionType.new(:Time, :time, "TIME", lambda {|argument, option_parser| return Time.zone.parse(argument) }, Time)
    OptionType.new(:DateTime, :time, "TIME", lambda {|argument, option_parser| return Time.zone.parse(argument) }, DateTime)
    OptionType.new(:Choice, :choice, "CHOICE", lambda {|argument, option_parser|
                     choice = argument.to_sym
                     choices = option_parser.choices
                     unless choices.blank?
                       unless choices.include? choice
                         raise BadChoiceError.new("invalid choice '#{choice}' not in list of choices: #{choices.map(&:to_s).join(', ')}")
                       end
                     end
                     return choice
                   }, Symbol)
    OptionType.new(:Hash, :hash, "K1=V1,K2=V2,K3=V3...", lambda {|argument, option_parser| return Hash[argument.split(',').map{|ai| ai.split('=')}] }, Hash)
    OptionType.new(:Ints, :ints, "INT1,INT2,INT3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_i) }, lambda {|value| return value.class == Array && value.first.class == Fixnum })
    OptionType.new(:Integers, :ints, "INT1,INT2,INT3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_i) }, lambda {|value| return value.class == Array && value.first.class == Fixnum })
    OptionType.new(:Floats, :floats, "NUM1,NUM2,NUM3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_f) }, lambda {|value| return value.class == Array && value.first.class == Float })
    OptionType.new(:Numbers, :numbers, "NUM1,NUM2,NUM3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_f) }, lambda {|value| return value.class == Array && value.first.class == Float })
    OptionType.new(:Strings, :strings, "STR1,STR2,STR3...", lambda {|argument, option_parser| return argument.split(',').map(&:to_s) }, lambda {|value| return value.class == Array && value.first.class == String })
    OptionType.new(:Uris, :uris, "URL1,URL2,URL3...", lambda {|argument, option_parser| return argument.split(',').map{|a| URI.parse(a)} }, lambda {|value| return value.class == Array && value.first.class == URI::HTTP })
    OptionType.new(:Dates, :dates, "DATE1,DATE2,DATE3...", lambda {|argument, option_parser| return argument.split(',').map{|a| Time.zone.parse(a).to_date} }, lambda {|value| return value.class == Array && value.first.class == Date })
    OptionType.new(:Times, :times, "TIME1,TIME2,TIME3...", lambda {|argument, option_parser| return argument.split(',').map{|a| Time.zone.parse(a) } }, lambda {|value| return value.class == Array && value.first.class == Time })
    OptionType.new(:DateTimes, :times, "TIME1,TIME2,TIME3...", lambda {|argument, option_parser| return argument.split(',').map{|a| Time.zone.parse(a) } }, lambda {|value| return value.class == Array && value.first.class == DateTime })
    OptionType.new(:Choices, :choices, "CHOICE1,CHOICE2,CHOICE3...", lambda {|argument, option_parser|
                     choice_list = argument.split(',').map(&:to_sym)
                     choices = option_parser.choices
                     unless choices.blank?
                       choice_list.each do |choice|
                         unless choices.include? choice
                           raise BadChoiceError.new("invalid choice '#{choice}' not in list of choices: #{choices.map(&:to_s).join(', ')}")
                         end
                       end
                     end
                     return choice_list
                   }, lambda {|value| return value.class == Array && value.first.class == Symbol })
  end
end
