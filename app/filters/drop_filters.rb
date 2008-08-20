module DropFilters
  def section(path)
    @context['site'].find_section(path)
  end
  
  def child_sections(path_or_section)
    path = path_or_section.is_a?(SectionDrop) ? path_or_section['path'] : path_or_section
    @context['site'].find_child_sections(path)
  end

  def descendant_sections(path_or_section)
    path = path_or_section.is_a?(SectionDrop) ? path_or_section['path'] : path_or_section
    @context['site'].find_descendant_sections(path)
  end
  
  def linked_section_list(article, separator = ', ')
    article.sections.collect {|s| link_to_section s }.join(separator)
  end
  
  def linked_tag_list(article, separator = ', ')
    article.tags.collect {|t| link_to_tag t }.join(separator)
  end

  def latest_articles(site_or_section, limit = nil)
    site_or_section.latest_articles(limit || site_or_section['articles_per_page'])
  end

  def latest_article(section)
    latest_articles(section, 1).first
  end
  
  def latest_comments(site, limit = nil)
    site.latest_comments(limit || site['articles_per_page'])
  end
  
  def find_asset(article, label)
    article.assets.detect { |a| a.source.label == label }
  end
  
  def next_article(article, section=nil)
    if nxt = article.source.next(section ? section.source : nil)
      nxt.to_liquid.tap { |n| n.context = @context if n }
    end
  end
  
  def previous_article(article, section=nil)
    if prev = article.source.previous(section ? section.source : nil)
      prev.to_liquid.tap { |p| p.context = @context if p }
    end
  end

  def monthly_articles(section, date = nil)
    date = parse_date(date)
    liquify(*section.source.articles.find_all_in_month(date.year, date.month)) { |r| r.to_liquid :mode => :single }
  end
  
  def tagged_articles(tags)
    liquify(*@context['site'].source.articles.find(:all, :include => :tags, :conditions => ['tags.name in (?)', Tag.parse(tags)], :order => 'contents.created_at desc'))
  end
  
  def tagged_articles_in_section(tags, section)
    liquify(*section.source.articles.find(:all, :include => :tags, :conditions => ['tags.name in (?)', Tag.parse(tags)], :order => 'contents.published_at desc'))
  end
  
  def assets_by_type(type, drop = nil)
    drop ||= @context['site']
    liquify(*drop.source.assets.find_all_by_content_types([type.to_sym], :all, :order => 'created_at desc'))
  end
  
  def tagged_assets(tags, drop = nil)
    drop ||= @context['site']
    liquify(*drop.source.assets.find(:all, :include => :tags, :conditions => ['tags.name in (?)', Tag.parse(tags)], :order => 'assets.created_at desc'))
  end
end