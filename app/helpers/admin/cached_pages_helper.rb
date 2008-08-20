module Admin::CachedPagesHelper
  def display_cached_page_date(page)
    if Date.today == page.updated_at.to_date 
      if page.updated_at > Time.now - 4.hours
        "#{time_ago_in_words(page.updated_at).gsub(/about /,'~ ')} ago"
      else
        "Today, #{page.updated_at.strftime('%l:%M %p')}"
      end
    else
      page.updated_at.strftime("%b %d, %Y")
    end
  end
end
