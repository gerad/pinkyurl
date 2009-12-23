class KeysController < ApplicationController
  def show
    @key = Key.from_param params[:id]

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @key }
      format.json { render :json => @key }
    end
  end

  def create
    @key = Key.new

    if @key.save
      respond_to do |format|
        format.xml  { render :xml => @key, :status => :created, :location => @key }
        format.json { render :json => @key, :status => :created, :location => @key }
      end
    else
      respond_to do |format|
        format.xml  { render :xml => @key.errors, :status => :unprocessable_entity }
        format.json { render :json => @key.errors, :status => :unprocessable_entity }
      end
    end
  end
end
