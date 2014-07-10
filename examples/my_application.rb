class MyApplication < ::Af::Application
  opt :word, "the word", :short => :w, :default => "bird"

  def work
    logger.info "Started up: #{@word} is the word"
    exit 0
  end
end
