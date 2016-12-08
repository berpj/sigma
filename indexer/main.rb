require_relative 'index'
require 'work_queue'

max_threads = ENV['MAX_THREADS'].to_i > 0 ? ENV['MAX_THREADS'].to_i : 1

wq = WorkQueue.new(max_threads)

loop do
  max_threads.times do
    wq.enqueue_b do
      index = Index.new
      index.delete_error_docs
      index.set_docs_to_index
      index.start
      index.close
    end
  end

  wq.join

  #GC.start if

  sleep(0.5)
end
