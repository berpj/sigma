# Parse HTML
class Parse
  require 'nokogiri'

  def parse_links(doc)
    title = doc[:content].match(/<title>(.*?)<\/title>/)
    title = (title) ? title[1] : ''

    html = Nokogiri::HTML(doc[:content])

    hrefs = []
    html.css("a").each do |a|
      hrefs << a.attr('href').strip if ! a.attr('href').nil? && ! a.attr('href').empty? && (a.attr('href').start_with?('http') || a.attr('href').start_with?('/')) && ! a.attr('href').match(/\s/) && a.attr('href').ascii_only?
    end

    begin
      urls = []
      hrefs.each do |href|
        url = URI.unescape(URI.join(doc[:url], href).to_s.force_encoding("UTF-8"))
        url = url.encode("UTF-8", 'binary', invalid: :replace, undef: :replace, replace: '') unless url.valid_encoding?
        urls << url
      end
    rescue URI::InvalidURIError
      return title, []
    end

    # Drop query strings and # part
    urls.map! { |url| url.split('#')[0] }
    
    return title, urls.uniq.first(200)
  end

  def parse_words(title, doc)
    require 'i18n'

    I18n.config.available_locales = :en

    doc = Nokogiri::HTML(doc[:content])

    doc.css('head, script, link').each { |node| node.remove unless node.nil? } # Remove useless html nodes
    text = doc.css('body').text

    text = "#{title} #{text}"
    text = text.tr("\n", ' ').downcase # Normalize text
    words = text.split(/\W+/) # Text to array of words

    result = []
    words_count = words.count
    position = 0
    words.each do |word|
      result << { word: word, position: (1. - (position / words_count.to_f)).round(5) }
      position += 1
    end

    result
  end
end
