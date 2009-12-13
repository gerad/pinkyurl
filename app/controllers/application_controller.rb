# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  filter_parameter_logging :password, :password_confirmation
  helper_method :person, :person_session

  def redirect_back_or path
    begin
      redirect_to :back
    rescue ActionController::RedirectBackError
      redirect_to path
    end
  end

private
  def person_session
    @authlogic_person_session ||= PersonSession.find
  end

  def person
    @authlogic_person ||= person_session.try :person
  end
end
