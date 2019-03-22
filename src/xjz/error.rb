class Exception
  def log_inspect
    "#{message}: \n#{backtrace.join("\n")}"
  end
end
