require File.dirname(__FILE__) + '/../test_helper'

class SiteDropTest < Test::Unit::TestCase
  fixtures :sites, :sections, :tags, :taggings, :contents
  
  def setup
    @site = sites(:first).to_liquid
    @site.context = mock_context
  end

  def test_equality
    assert_equal @site, sites(:first)
    assert_equal @site, sites(:first).to_liquid
  end

  def test_should_convert_site_to_drop
    assert_kind_of Liquid::Drop, sites(:first).to_liquid
  end

  def test_should_list_all_sections
    assert_models_equal [sections(:home), sections(:about), sections(:earth), sections(:europe), sections(:africa), sections(:bucharest), sections(:links), sections(:paged_section)], @site.sections.collect(&:source)
    assert_equal [false, false, false, false, false, false, false, false], @site.sections.collect(&:current)
  end
  
  def test_should_default_to_no_current_section
    assert_nil @site.current_section
  end
  
  def test_should_show_current_section
    @site = SiteDrop.new(sites(:first), sections(:about))
    @site.context = mock_context
    assert_equal sections(:about), @site.current_section.source
    assert_equal [false, true, false, false, false, false, false, false], @site.sections.collect(&:current)
  end
  
  def test_should_list_only_blog_sections
    assert_models_equal [sections(:home), sections(:earth), sections(:europe), sections(:africa), sections(:bucharest)], @site.blog_sections.collect(&:source)
  end
  
  def test_should_list_only_paged_sections
    assert_models_equal [sections(:about), sections(:links), sections(:paged_section)], @site.page_sections.collect(&:source)
  end

  def test_should_list_tags
    assert_equal %w(mongrel rails ruby), @site.tags
  end

  def test_should_find_home_section
    assert_equal sections(:home), @site.home_section.source
  end

  def test_should_find_section_by_path
    assert_equal sections(:about), @site.find_section('about').source
  end

  def test_should_find_latest_articles
    assert_models_equal [contents(:welcome), contents(:about), contents(:site_map), contents(:another), contents(:at_beginning_of_next_month), contents(:article_1_only_in_page_section), contents(:article_2_only_in_page_section), contents(:at_end_of_month), contents(:at_middle_of_month), contents(:at_beginning_of_month)], 
      @site.latest_articles.collect(&:source)
    assert_models_equal [contents(:welcome), contents(:about)], @site.latest_articles(2).collect(&:source)
  end

  def test_should_find_latest_comments
    assert_models_equal [contents(:welcome_comment)], @site.latest_comments.collect(&:source)
    assert_models_equal [contents(:welcome_comment)], @site.latest_comments(1).collect(&:source)
  end

  def test_liquid_keys
    [:host, :subtitle, :title, :articles_per_page].each do |attr|
      assert_equal sites(:first).send(attr), @site.before_method(attr)
    end
  end
end
