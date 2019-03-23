class Exception
  def log_inspect
    "#{self.class} #{message}: \n#{backtrace.join("\n")}"
  end
end
