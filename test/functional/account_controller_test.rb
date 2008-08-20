require File.dirname(__FILE__) + '/../test_helper'
require_dependency 'account_controller'

# Re-raise errors caught by the controller.
class AccountController; def rescue_action(e) raise e end; end

context "Account Controller Login" do
  fixtures :users, :sites, :memberships

  def setup
    @controller = AccountController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  specify "should login as mephisto admin" do
    post :login, :login => 'quentin', :password => 'test'
    assert session[:user]
    # quentin has User.admin true
    assert_redirected_to :controller => 'admin/overview', :action => 'index'
  end

  specify "should login as site member" do
    post :login, :login => 'arthur', :password => 'test'
    assert session[:user]
    # arthur is an admin for the site :first
    assert_redirected_to :controller => 'admin/overview', :action => 'index'
    get :logout
    assert !session[:user]
  end

  specify "should login as site user" do
    post :login, :login => 'ben', :password => 'test'
    assert session[:user]
    # ben is not an admin so should be redirected to the front page
    assert_redirected_to :controller => 'mephisto', :action => 'dispatch'
    get :logout
    assert !session[:user]
  end

  specify "should fail login and not redirect" do
    post :login, :login => 'quentin', :password => 'bad password'
    assert_nil session[:user]
    assert_response :success
  end

  specify "should fail login for disabled user and not redirect" do
    post :login, :login => 'aaron', :password => 'test'
    assert_nil session[:user]
    assert_response :success
  end

  specify "should logout" do
    login_as :quentin
    get :logout
    assert_nil session[:user]
    assert_redirected_to dispatch_path
    assert_response :redirect
  end
end

context "Account Controller Cookie" do
  fixtures :users, :sites, :memberships

  def setup
    @controller = AccountController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  specify "should remember me" do
    post :login, :login => 'quentin', :password => 'test', :remember_me => "1"
    assert_not_nil @response.cookies['token']
  end

  specify "should not remember me" do
    post :login, :login => 'quentin', :password => 'test', :remember_me => "0"
    assert_nil cookies[:auth_token]
  end
  
  specify "should delete token on logout" do
    @request.cookies["token"] = cookie_for(:quentin)
    login_as :quentin
    get :logout
    assert_equal @response.cookies['token'], []
  end

  specify "should login with cookie" do
    @request.cookies["token"] = cookie_for(:quentin)
    get :index
    assert @controller.send(:logged_in?)
  end

  specify "should fail cookie login with expired token" do
    @request.cookies["token"] = cookie_for(:arthur)
    get :index
    assert !@controller.send(:logged_in?)
  end

  specify "should fail cookie login with invalid token" do
    @request.cookies["token"] = auth_token('invalid_auth_token')
    get :index
    assert !@controller.send(:logged_in?)
  end

  protected
    def auth_token(token)
      CGI::Cookie.new('name' => 'token', 'value' => token)
    end
    
    def cookie_for(user)
      auth_token users(user).token
    end
    
    def create_user(options = {})
      post :signup, :user => { :login => 'quire', :email => 'quire@example.com', 
        :password => 'quire', :password_confirmation => 'quire' }.merge(options)
    end
end

context "Account Controller Password Reset" do
  fixtures :users, :sites, :memberships

  def setup
    @controller = AccountController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @emails = ActionMailer::Base.deliveries 
    @emails.clear
  end

  specify "should ignore invalid reset attempt" do
    assert_no_difference @emails, :size do
      get :forget
    end
    assert_redirected_to :action => 'login'
    assert flash[:error]
    assert_nil flash[:notice]
  end

  specify "should ignore reset attempt with missing email" do
    assert_no_difference @emails, :size do
      post :forget
    end
    assert_redirected_to :action => 'login'
    assert flash[:error]
    assert_nil flash[:notice]
  end

  specify "should ignore reset attempt with bad email" do
    assert_no_difference @emails, :size do
      post :forget, :email => 'foobar'
    end
    assert_redirected_to :action => 'login'
    assert flash[:error]
    assert_nil flash[:notice]
  end
  
  specify "should send user token by email on good email" do
    old_token = users(:quentin).token
    assert_difference @emails, :size do
      post :forget, :email => users(:quentin).email
    end
    
    assert old_token != users(:quentin).reload.token
    assert_equal users(:quentin).email, @emails.first.to.first
    assert flash[:notice]
    assert_nil flash[:error]
  end
  
  specify "should activate valid token" do
    old_token = users(:quentin).token
    get :activate, :id => users(:quentin).token
    assert_equal users(:quentin), @controller.send(:current_user)
    assert old_token != users(:quentin).reload.token
    assert_redirected_to :controller => 'admin/users', :action => 'show', :id => users(:quentin)
    assert_nil flash[:error]
  end
  
  specify "should not activate invalid token" do
    old_token = users(:arthur).token
    get :activate, :id => users(:arthur).token
    assert !@controller.send(:logged_in?)
    assert_equal old_token, users(:arthur).reload.token
    assert_redirected_to :action => 'login'
    assert flash[:error]
  end
end
