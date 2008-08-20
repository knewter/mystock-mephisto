class BaseConverter
  @@new_user_password = 'mephistomigrator'
  cattr_accessor :new_user_password

  def initialize(options = {})
    @count   = {:users => 0, :articles => 0, :comments => 0}
    @options = options
  end

  # Converts the source blog to mephisto.  Should resemble something like this:
  #
  #   converter = new(options)
  #   converter.import_users do |other_user|
  #     # build Mephisto User object from other user
  #     ::User.new ...
  #   end
  #   
  #   convert.import_articles do |other_article|
  #     # build Mephisto Article object from other article
  #     ::Article.new ...
  #   end
  #   
  #   convert.import_comments do |other_comment|
  #     # build Mephisto Comment object from other comment
  #     ::Comment.new ...
  #   end
  def self.convert(options = {})
    raise NotImplementedError
  end

  # override this to provide array of all posts to migrate.
  #
  #   @old_articles ||= Article.find(:all)
  def old_articles
    raise NotImplementedError
  end

  # override this to find all users from the source database
  # save them to @old_users, indexed by :login
  # 
  #   @old_users ||= User.find(:all).index_by(&:login)
  def old_users
    raise NotImplementedError
  end
  
  # override this to find all assets from the source database.
  # Save them to @old_assets.
  #
  #   @old_assets = Asset.find(:all)
  def old_assets
    raise NotImplementedError
  end

  # override this to retrieve the login name from the source user model
  def get_login(other_user)
    other_user.login
  end

  # override this to retrieve all comments from the source article model
  def comments_for(other_article)
    other_article.comments
  end

  # Resets an invalid email for a new user
  def handle_bad_user_email(other_user, email)
    other_user.email = email
  end

  # Resets the author email for a bad comment from the source site.
  def handle_bad_comment_author_email(other_comment, email)
    other_comment.author_email = email
  end

  # Resets the author url for a bad comment from the source site.
  def handle_bad_comment_author_url(other_comment, url)
    other_comment.author_url = url
  end
  
  # Resets the author name for a bad comment from the source site.
  def handle_bad_comment_author(other_comment, author)
    other_comment.author = author
  end
  
  # Resets the content for a bad comment from the source site.
  def handle_bad_comment_content(other_comment, content)
    other_comment.content = content
  end

  # Returns the destination site for the migrated content.  Uses the :site => 5 option to specify a site by id.
  def site
    @site ||= ::Site.find(@options[:site] || 1)
  end

  # Returns all the users from the current Mephisto site, in a hash indexed by login name.
  def users
    if @users.nil?
      @users      ||= site.members
      @users        = ::User.find(:all) unless @users.any?
      @default_user = @users.first
      @users        = @users.index_by(&:login)
    end
    
    @users
  end

  # Returns the default user for new articles if one is not set in the source site.
  def default_user
    users if @users.nil?
    @default_user
  end

  # Returns all the sections from the current Mephisto site, in a hash indexed by the section path.
  def sections
    @sections ||= site.sections.index_by(&:path)
  end

  def import_users(&block)
    old_users.each do |login, other_user|
      import_user(other_user, &block)
    end
    puts "migrated #{@count[:users]} user(s)..."
  end
  
  def import_user(other_user, &block)
    unless other_user && users[get_login(other_user)]
      ActiveRecord::Base.logger.info "Creating new user for #{get_login(other_user)}"
      new_user = block.call(other_user)
      new_user.save!
      @count[:users] += 1
      new_user
    end
  rescue ActiveRecord::RecordInvalid
    if $!.record.errors.on :email
      puts "  Retrying with new email"
      handle_bad_user_email other_user, "#{$!.record.login}@nodomain.com"
      retry
    else
      raise
    end
  end

  def create_article(other_article, &block)
    if article = block.call(other_article)
      article.site        = site
      article.user      ||= default_user
      article.updater   ||= default_user
      article.filter    ||= "#{@options[:filter] || :textile}_filter"
      article.author_ip ||= '127.0.0.1'
      article.save!
      @article_index[other_article] = article
      @count[:articles] += 1
    end
  rescue ActiveRecord::RecordInvalid
    puts "Invalid Article: %s " % $!.record.errors.full_messages.join(' ')
    puts $!.record.inspect
    raise
  end

  def create_comment(article, other_comment, &block)
    ActiveRecord::Base.logger.info "adding comment"
    returning block.call(other_comment) do |comment|
      comment.article_id  = article.id
      comment.filter    ||= site.filter
      comment.author_ip ||= '127.0.0.1'
      comment.approved    = true
      comment.save!
      @count[:comments] += 1
    end
  rescue ActiveRecord::RecordInvalid
    if $!.record.errors.on :author_email
      puts "  Retrying with new email"
      handle_bad_comment_author_email other_comment, "invalid@nodomain.com"
      retry
    elsif $!.record.errors.on :author_url
      puts "  Retrying with new URL"
      handle_bad_comment_author_url other_comment, "http://nowhere.com/"
      retry
    elsif $!.record.errors.on :author
      puts "  Retrying with new author name"
      handle_bad_comment_author other_comment, "unknown"
      retry
    elsif $!.record.errors.on :body
      puts "  Retrying with blank body"
      handle_bad_comment_content other_comment, "empty"
      retry
    end
    puts "Invalid Comment: %s " % $!.record.errors.full_messages.join(' ')
    puts $!.record.inspect
    raise
  end
  
  def import_articles(&block)
    @article_index = {}
    old_articles.each do |other_article|
      create_article other_article, &block
    end
    puts "migrated #{@count[:articles]} article(s)..."
  end
  
  def import_comments(&block)
    old_articles.each do |other_article|
      ActiveRecord::Base.logger.info "Creating article comments"
      comments_for(other_article).each do |other_comment|
        create_comment(@article_index[other_article], other_comment, &block)
      end
    end
    puts "migrated #{@count[:comments]} comment(s)..."
  end
end

