require_relative 'crawl'
require 'work_queue'

max_threads = ENV['MAX_THREADS'].to_i > 0 ? ENV['MAX_THREADS'].to_i : 1

wq = WorkQueue.new(max_threads)

loop do
  max_threads.times do
    wq.enqueue_b do
      crawl = Crawl.new
      crawl.set_docs_to_crawl
      crawl.start
      crawl.close
    end
  end

  wq.join

  sleep(0.5)
end
