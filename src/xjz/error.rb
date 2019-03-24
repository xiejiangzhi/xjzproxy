class Exception
  def log_inspect
    bts = backtrace.select { |bt| bt[$root] }
    "#{self.class} #{message}: \n#{bts.join("\n")}"
  end
end
