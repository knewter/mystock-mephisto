class Admin::BaseController < ApplicationController
  class_inheritable_reader :member_actions
  write_inheritable_attribute :member_actions, []
  include AuthenticatedSystem
  before_filter :protect_action, :only => [:create, :update, :destroy]
  before_filter { |c| UserMailer.default_url_options[:host] = c.request.host_with_port }
  before_filter :login_from_cookie
  before_filter :login_required, :except => :feed

  protected
    def protect_action
      if request.get?
        if params[:id]
          redirect_to :action => 'show', :id => params[:id]
        else
          redirect_to :action => 'index'
        end
      else
        true
      end
    end

    # standard authorization method.  allow logged in users that are admins, or members in certain actions
    def authorized?
      logged_in? && (admin? || member_actions.include?(action_name) || allow_member?)
    end

    # further customize the authorization process, for those special methods that require extra validation
    def allow_member?
      true
    end

    def find_and_sort_templates
      @layouts, @templates = site.templates.partition { |t| t.dirname.to_s =~ /layouts$/ }
    end
    
    def self.clear_empty_templates_for(model, *attributes)
      options = attributes.last.is_a?(Hash) ? attributes.pop : {}
      before_filter(options) { |c| attributes.each { |attr| c.params[model][attr] = nil if c.params[model][attr] == '-' } }
    end
end
