class Numeric
  def seconds
    self
  end
  alias :second :seconds

  def minutes
    self * 60
  end
  alias :minute :minutes

  def hours
    self * 3600
  end
  alias :hour :hours

  def days
    self * 3600 * 24
  end
  alias :day :days

  def weeks
    self * 3600 * 24 * 7
  end
  alias :week :weeks
end

class Integer
  def months
    self * 3600 * 24 * 30
  end
  alias :month :months

  def years
    self * 3600 * 24 * 365
  end
  alias :year :years
end
