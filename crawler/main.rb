require_relative 'crawler'
require 'work_queue'

max_threads = ENV['MAX_THREADS'].to_i > 0 ? ENV['MAX_THREADS'].to_i : 1

wq = WorkQueue.new(max_threads)

loop do
  wq.enqueue_b do
    crawler = Crawler.new()
    crawler.start
  end

  wq.join

  sleep(0.1)
end
