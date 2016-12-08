# Parse HTML
class Parse
  attr_reader :urls, :title, :description, :words

  def initialize(doc)
    require 'nokogiri'

    @url = doc[:url]
    @html = Nokogiri::HTML(doc[:content])
    @title = nil
    @description = nil
    @words = []
    @urls = []
  end

  def start
    update_urls
    update_title
    update_description
    update_words
  end

  private

  def update_urls
    hrefs = []
    @html.css("a").each do |a|
      hrefs << a.attr('href').strip if ! a.attr('href').nil? && ! a.attr('href').empty? && (a.attr('href').start_with?('http') || a.attr('href').start_with?('/')) && ! a.attr('href').match(/\s/) && a.attr('href').ascii_only?
    end

    begin
      hrefs.each do |href|
        url = URI.unescape(URI.join(@url, href).to_s.force_encoding("UTF-8"))
        url = url.encode("UTF-8", 'binary', invalid: :replace, undef: :replace, replace: '') unless url.valid_encoding?
        @urls << url
      end
    rescue URI::InvalidURIError
      @urls = []
      return
    end

    # Drop query strings and # part
    @urls.map! { |url| url.split('#')[0] }

    @urls.uniq.first(200)
  end

  def update_title
    tag = @html.css('title')
    puts tag
    puts tag.text
    @title = tag.text.force_encoding('utf-8') unless tag.nil? || tag.text.nil?
  end

  def update_description
    tags = @html.css('meta[name="description"]')
    @description = tags.first['content'].force_encoding('utf-8') unless tags.nil? || tags.first.nil?
  end

  def update_words
    require 'i18n'

    @html.css('head, script, link').each { |node| node.remove unless node.nil? } # Remove useless html nodes
    text = @html.css('body').text

    text = "#{@title} #{text}"
    text = text.tr("\n", ' ').downcase # Normalize text
    text_array = text.split(/\W+/) # Text to array of words

    words_count = text_array.count
    position = 0
    text_array.each do |word|
      @words << { word: word, position: (1. - (position / words_count.to_f)).round(5) }
      position += 1
    end
  end
end
