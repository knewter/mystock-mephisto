class Asset < ActiveRecord::Base
  # used for extra mime types that dont follow the convention
  @@extra_content_types = { :audio => ['application/ogg'], :movie => ['application/x-shockwave-flash'], :pdf => ['application/pdf'] }.freeze
  cattr_reader :extra_content_types

  # use #send due to a ruby 1.8.2 issue
  @@movie_condition = send(:sanitize_sql, ['content_type LIKE ? OR content_type IN (?)', 'video%', extra_content_types[:movie]]).freeze
  @@audio_condition = send(:sanitize_sql, ['content_type LIKE ? OR content_type IN (?)', 'audio%', extra_content_types[:audio]]).freeze
  @@image_condition = send(:sanitize_sql, ['content_type IN (?)', Technoweenie::AttachmentFu.content_types]).freeze
  @@other_condition = send(:sanitize_sql, [
    'content_type NOT LIKE ? AND content_type NOT LIKE ? AND content_type NOT IN (?)',
    'audio%', 'video%', (extra_content_types[:movie] + extra_content_types[:audio] + Technoweenie::AttachmentFu.content_types)]).freeze
  cattr_reader *%w(movie audio image other).collect! { |t| "#{t}_condition".to_sym }

  class << self
    def movie?(content_type)
      content_type.to_s =~ /^video/ || extra_content_types[:movie].include?(content_type)
    end
        
    def audio?(content_type)
      content_type.to_s =~ /^audio/ || extra_content_types[:audio].include?(content_type)
    end
    
    def other?(content_type)
      ![:image, :movie, :audio].any? { |a| send("#{a}?", content_type) }
    end

    def pdf?(content_type)
      extra_content_types[:pdf].include? content_type
    end

    def find_all_by_content_types(types, *args)
      with_content_types(types) { find *args }
    end

    def with_content_types(types, &block)
      with_scope(:find => { :conditions => types_to_conditions(types).join(' OR ') }, &block)
    end

    def types_to_conditions(types)
      types.collect! { |t| '(' + send("#{t}_condition") + ')' }
    end
  end

  include Mephisto::TaggableMethods

  belongs_to :site
  has_many :assigned_assets, :order => 'position', :dependent => :destroy
  has_attachment :storage => :file_system, :thumbnails => { :thumb => '120>', :tiny => '50>' }, :max_size => 30.megabytes, 
    :processor => (Object.const_defined?(:ASSET_IMAGE_PROCESSOR) ? ASSET_IMAGE_PROCESSOR : nil)
  before_validation_on_create :set_site_from_parent
  validates_presence_of :site_id
  validates_as_attachment
  validate :rename_unique_filename

  def full_filename(thumbnail = nil)
    file_system_path = (thumbnail ? thumbnail_class : self).attachment_options[:file_system_path]
    File.join(RAILS_ROOT, 'public/assets', permalink, thumbnail_name_for(thumbnail))
  end

  def public_filename_with_host(thumbnail = nil)
    returning public_filename_without_host(thumbnail) do |s|
      s.gsub! /^\/assets\/[^\/]+\//, "/assets/#{$1}" if Site.multi_sites_enabled
    end
  end
  alias_method_chain :public_filename, :host

  def title
    t = read_attribute(:title)
    t.blank? ? filename : t
  end

  after_attachment_saved do |record|
    File.chmod 0644, record.full_filename
    Asset.update_all ['thumbnails_count = ?', record.thumbnails.count], ['id = ?', record.id] unless record.parent_id
  end

  [:movie, :audio, :other, :pdf].each do |content|
    define_method("#{content}?") { self.class.send("#{content}?", content_type) }
  end

  def to_liquid
    AssetDrop.new self
  end

  protected
    def rename_unique_filename
      if ((@old_filename && !@old_filename.eql?(full_filename)) || new_record?) && errors.empty? && site_id && filename
        i      = 1
        pieces = filename.split('.')
        ext    = pieces.size == 1 ? nil : pieces.pop
        base   = pieces * '.'
        while File.exists?(full_filename)
          write_attribute :filename, base + "_#{i}#{".#{ext}" if ext}"
          i += 1
        end
      end
    end

    def permalink
      date = created_at || Time.now.utc
      pieces = [site.host, date.year, date.month, date.day]
      pieces.shift unless Site.multi_sites_enabled
      pieces * '/'
    end
    
    def set_site_from_parent
      self.site_id = parent.site_id if parent_id
    end
end
