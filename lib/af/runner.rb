class Af::Runner

  code_or_file = nil

  if ARGV.first.nil?
    $stderr.puts "Input a class name"
    exit
  else
    code_or_file = ARGV.first
  end

  APP_PATH = `pwd`.chop! + '/config/application.rb'
  if File.exist?(APP_PATH)
    require APP_PATH
  else
    $stderr.puts "Go to the root project directory"
    exit
  end

  Rails.application.require_environment!
  begin
    eval(code_or_file)
  rescue SyntaxError
    $stderr.puts "#{code_or_file} - a class name is invalid"
  end
end