require_relative 'pagerank'

loop do
  pagerank = PageRank.new
  pagerank.set_docs_to_index
  pagerank.update_index
  pagerank.start
  pagerank.close

  sleep(0.5)
end
