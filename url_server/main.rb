require_relative 'serve_urls'
require 'work_queue'

max_threads = ENV['MAX_THREADS'].to_i > 0 ? ENV['MAX_THREADS'].to_i : 1

wq = WorkQueue.new(max_threads)

loop do
  max_threads.times do
    wq.enqueue_b do
      serve_urls = ServeUrls.new
      serve_urls.update_new_docs_to_crawl
      serve_urls.update_docs_to_recrawl
      serve_urls.send_docs_to_crawler
      serve_urls.close
    end
  end

  wq.join

  sleep(0.5)
end
