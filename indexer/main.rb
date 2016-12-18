require_relative 'index'

loop do
  index = Index.new
  index.delete_error_docs
  index.set_docs_to_index
  index.start
  index.close

  sleep(0.5)
end
