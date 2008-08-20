require 'flickr'
class FlickrMacro < FilteredColumn::Macros::Base
  KEY = '84f652422f05b96b29b9a960e0081c50'

  def self.filter(attributes, inner_text = '', text = '')
    img     = attributes[:img]
    size    = attributes[:size] || "square"
    style   = attributes[:style]
    caption = attributes[:caption]
    title   = attributes[:title]
    alt     = attributes[:alt]

    flickr      = Flickr.new(attributes[:key] || KEY)
    flickrimage = Flickr::Photo.new(img)
    sizes       = flickrimage.sizes

    details   = sizes.find {|s| s['label'].downcase == size.downcase } || sizes.first
    width     = details['width']
    height    = details['height']
    imageurl  = details['source']
    imagelink = flickrimage.url

    caption ||= flickrimage.description
    title   ||= flickrimage.title
    alt     ||= title

    if(caption.blank?)
      captioncode = ""
    else
      captioncode = "<p class=\"caption\" style=\"width:#{width}px\">#{caption}</p>"
    end

    "<div style=\"#{style}\" class=\"flickrplugin\"><a href=\"#{imagelink}\"><img src=\"#{imageurl}\" width=\"#{width}\" height=\"#{height}\" alt=\"#{alt}\" title=\"#{title}\"/></a>#{captioncode}</div>"
  end
end