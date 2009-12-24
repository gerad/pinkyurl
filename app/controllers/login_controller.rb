class LoginController < ApplicationController
  def new
    @person_session = PersonSession.new
  end

  def create
    @person_session = PersonSession.new(params[:person_session])
    if @person_session.save
      flash[:notice] = "Login successful!"
      redirect_to person
    else
      render :action => :new
    end
  end

  def destroy
    person_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or root_url
  end
end
