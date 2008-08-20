require 'digest/md5'
module UrlFilters
  include Mephisto::Liquid::UrlMethods
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper

  def link_to_article(article, *args)
    options = link_args_to_options(args)
    text = options.delete(:text) || h(article['title'])
    content_tag :a, text, { :href => article['url'], :title => text }.merge(options)
  end
  
  def link_to_page(page, section = nil, *args)
    options = link_args_to_options(args)
    text = options.delete(:text) || h(page['title'])
    content_tag :a, text, page_anchor_options(page, section, { :title => text }.merge(options))
  end

  def link_to_comments(article, *args)
    options = link_args_to_options(args)
    text = options.delete(:text) || pluralize(article['comments_count'], 'comment')
    content_tag :a, text, { :href => article['url'] + '#comments', :title => text }.merge(options)
  end
  
  def link_to_section(section, *args)
    options = link_args_to_options(args)
    text = options.delete(:text) || h(section['name'])
    content_tag :a, text, section_anchor_options(section, { :title => text }.merge(options))
  end

  def img_tag(img, options = {})
    tag 'img', {:src => asset_url(img), :alt => img.split('.').first }.merge(options)
  end
  
  # Special link that checks for current section.  If it exists and it's a paged section, use link_to_page instead.
  def link_to_search_result(article, *args)
    if current_page_section && current_page_section[:is_paged]
      link_to_page(article, current_page_section, *args)
    else
      link_to_article(article, *args)
    end
  end
  
  def stylesheet_url(css)
    absolute_url :stylesheets, css
  end
  
  def javascript_url(js)
    absolute_url :javascripts, js
  end
  
  def asset_url(asset)
    absolute_url :images, asset
  end

  def stylesheet(stylesheet, media = nil)
    stylesheet << '.css' unless stylesheet.include? '.'
    tag 'link', :rel => 'stylesheet', :type => 'text/css', :href => stylesheet_url(stylesheet), :media => media
  end

  def javascript(javascript)
    javascript << '.js' unless javascript.include? '.'
    content_tag 'script', '', :type => 'text/javascript', :src => javascript_url(javascript)
  end

  def gravatar(comment, size=80, default=nil)
    return '' unless comment['author_email']
    url = "http://www.gravatar.com/avatar.php?size=#{size}&gravatar_id=#{Digest::MD5.hexdigest(comment['author_email'])}"
    url << "&default=#{default}" if default

    image_tag url, :class => 'gravatar', :size => "#{size}x#{size}", :alt => comment['author']
  end

  def link_to_tag(tag, *args)
    options = link_args_to_options(args)
    text = options.delete(:text) || h(tag)
    content_tag :a, text, { :href => tag_url(tag), :rel => 'tag', :title => text }.merge(options)
  end

  def link_to_month(section, date = nil, format = 'my', *args)
    options = link_args_to_options(args)
    text = options.delete(:text) || h(format_date(date, format))
    content_tag :a, text, { :href => monthly_url(section, date), :title => text }.merge(options)
  end

  def monthly_url(section, date = nil)
    date = parse_date(date)
    archive_url(section, date.year.to_s, date.month.to_s)
  end

  def archive_url(section, *pieces)
    File.join(section.url, section['archive_path'], *pieces)
  end

  def tag_url(*tags)
    tags = [tags] ; tags.flatten!
    absolute_url @context['site'].source.tag_url(*tags)
  end

  def search_url(query, page = nil)
    absolute_url @context['site'].source.search_url(query, page)
  end

  def page_url(page, section = nil)
    section ||= current_page_section
    page[:is_page_home] ? section.url : section.url + (section.url == '/' ? '' : '/') + page[:permalink]
  end

  def atom_feed(url, title = nil)
    options = {:rel => 'alternate', :type => 'application/atom+xml', :href => absolute_url(url)}
    options[:title] = title unless title.blank?
    tag(:link, options)
  end

  def all_comments_feed(title = nil)
    atom_feed '/feed/all_comments.xml', title.blank? ? 'All Comments' : title
  end

  def comments_feed(section_or_article, title = nil)
    section_or_article.is_a?(SectionDrop) ?
      atom_feed('/feed/' + section_or_article.source.to_comments_url.join('/'), (title.blank? ? "Comments for #{section_or_article['name']}" : title)) :
      atom_feed(section_or_article.url + '/comments.xml', (title.blank? ? "Comments for #{section_or_article['title']}" : title))
  end

  def changes_feed(article, title = nil)
    atom_feed article.url + '/changes.xml', (title.blank? ? "Changes for #{article['title']}" : title)
  end

  def articles_feed(section, title = nil)
    atom_feed '/feed/' + section.source.to_feed_url.join('/'), (title.blank? ? "Articles for #{section['name']}" : title)
  end

  def next(article, section = nil)
    article.next(section)
  end

  def previous(article, section = nil)
    article.previous(section)
  end

  private
    # marks a page as class=selected
    def page_anchor_options(page, section = nil, options = {})
      options.update(:href => page_url(page, section))
      options[:class].nil? ? options.update(:class => 'selected') : options[:class] += ' selected' if current_page_article == page
      options
    end
    
    # marks a section as class=selected
    def section_anchor_options(section, options = {})
      options.update(:href => section['url'])
      options[:class].nil? ? options.update(:class => 'selected') : options[:class] += ' selected' if current_page_section && (current_page_section.url == section.url)
      options
    end
    
    def link_args_to_options(args)
      options = {}
      [:text, :title, :id, :class, :rel].zip(args) {|key, value| options[key] = h(value) unless value.blank?}
      options
    end
    
    def current_page_section
      @current_page_section ||= @context['section']
    end
    
    def current_page_article
      @current_page_article ||= @context['article']
    end
end
