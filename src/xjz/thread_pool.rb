module Xjz
  class ThreadPool
    attr_reader :max_size, :max_queue_size, :job_queue, :workers, :is_shutdown

    STATUS_KEY = :_xjz_thread_pool_status_
    LAST_RUN_KEY = :_xjz_thread_pool_last_run_at_
    THREAD_TIMEOUT = 60

    def initialize(max_size, max_queue_size = 0)
      @max_size = max_size
      @max_queue_size = max_queue_size

      @workers = []
      @job_queue = Thread::Queue.new
      @mutex = Mutex.new
      @is_shutdown = false
    end

    def post(*args, &block)
      raise "Block is required" unless block
      raise "Pool was shutdown" if @is_shutdown

      if (job_queue.size + total_active_workers) >= (max_queue_size + max_size)
        false
      else
        job_queue << [block, args]
        wake_up_workers
        true
      end
    end

    def total_active_workers
      workers.count { |w| w[STATUS_KEY] }
    end

    def kill
      @mutex.synchronize do
        job_queue.clear
        workers.each(&:kill)
        workers.clear
      end
    end

    def shutdown
      @is_shutdown = true
      kill
    end

    private

    def wake_up_workers
      @mutex.synchronize do
        workers.delete_if { |w| !w.alive? }
        return if workers.size >= max_size
        workers << new_worker
      end
    end

    def new_worker
      Thread.new do
        cthread = Thread.current
        cthread[STATUS_KEY] = false
        cthread[LAST_RUN_KEY] = Time.now

        loop do
          job, args = nil, nil
          if job_queue.size > 0
            job, args = job_queue.shift(true) rescue nil
          else
            sleep 0.1
          end

          if job
            cthread[STATUS_KEY] = true
            cthread[LAST_RUN_KEY] = Time.now
            job.call(*args)
          elsif (Time.now - cthread[LAST_RUN_KEY]) >= THREAD_TIMEOUT
            break
          end
        rescue => e
          Logger[:auto].error { e.log_inspect }
        ensure
          cthread[STATUS_KEY] = false
          cthread[LAST_RUN_KEY] = Time.now if job
        end
      end
    end
  end
end
