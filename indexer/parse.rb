# Parse HTML
class Parse
  attr_reader :urls, :title, :description, :lang, :words

  def initialize(doc)
    require 'i18n'
    require 'nokogiri'

    I18n.config.available_locales = :en

    @url = doc[:url]
    @html = Nokogiri::HTML(doc[:content])
    @title = nil
    @description = nil
    @lang = nil
    @words = []
    @urls = []

    @qualities = {
      'title' => 8.0 / 8,
      'h1' => 8.0 / 8,
      'h2' => 7.0 / 8,
      'h3' => 6.0 / 8,
      'h4' => 5.0 / 8,
      'h5' => 4.0 / 8,
      'h6' => 3.0 / 8,
      'strong' => 2.0 / 8,
      'b' => 2.0 / 8,
      'em' => 1.0 / 8,
      'u' => 1.0 / 8
    }
  end

  def start
    update_urls
    update_title
    update_description
    update_lang
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
    @title = tag.text.force_encoding('utf-8') unless tag.nil? || tag.text.nil?
  end

  def update_description
    tags = @html.css('meta[name="description"]')
    @description = tags.first['content'].force_encoding('utf-8') unless tags.nil? || tags.first.nil? || tags.first['content'].nil?
  end

  def update_lang
    @lang = @html.at('html')[:lang] unless @html.at('html').nil?
  end

  def update_words
    require 'stemmify'

    @html.css('head, script, link').each { |node| node.remove unless node.nil? } # Remove useless html nodes

    tmp_words = []

    parsed = parse_node('title', @title)
    tmp_words += parsed unless parsed.nil? || parsed.empty?

    @html.search('//text()').each do |node|
      parsed = parse_node(node.parent.node_name, node.text)
      tmp_words += parsed unless parsed.nil? || parsed.empty?
    end

    words_count = tmp_words.count
    position = 0
    tmp_words.each do |word|
      @words << { word: word[:text].stem, quality: word[:quality], position: (1.0 - (position / words_count.to_f)).round(5) } if @words.count { |x| x[:word] == word[:text] } < 3

      position += 1
    end
  end

  def parse_node(node_name, text)
    return nil if node_name.nil? || text.nil? || text !~ /\w/ || ! @qualities.key?(node_name)

    text = text.tr("\n", ' ').downcase.strip # Normalize text
    text = I18n.transliterate(text)

    return nil if text == ''

    text_array = text.split(/\W+/)

    tmp_words = []

    text_array.each { |word| tmp_words << {quality: @qualities[node_name], text: word} }

    tmp_words
  end
end
