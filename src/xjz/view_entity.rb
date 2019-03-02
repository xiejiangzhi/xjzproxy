class Xjz::ViewEntity
  def initialize(history)
    @history = history
  end

  def each_with_host(&block)
    @history.group_by do |req_tracker|
      req_tracker.request.host
    end.each(&block)
  end
end
