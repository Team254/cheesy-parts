# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# The main class of the parts management web server.

require "pathological"
require "sinatra/base"

require "models"

module CheesyParts
  class Server < Sinatra::Base
    set :sessions => true

    before do
      @user = User[session[:user_id]]
    end

    def authenticate!
      redirect "/login" if @user.nil?
    end

    get "/login" do
      @failed = params[:failed] == "1"
      erb :login
    end

    post "/login" do
      user = User.authenticate(params[:email], params[:password])
      redirect "/login?failed=1" if user.nil?
      session[:user_id] = user.id
    end

    get "/logout" do
      session[:user_id] = nil
      redirect "/"
    end
  
    get "/" do
      authenticate!
      "This page intentionally left blank, #{@user.email}."
    end

    post "/projects" do
      # Check parameter existence and format.
      halt(400, "Missing project name.") if params[:name].nil?
      if params[:part_number_prefix].nil? || params[:part_number_prefix] !~ /^\d+$/
        halt(400, "Missing or invalid part number prefix.")
      end

      Project.create(:name => params[:name], :part_number_prefix => params[:part_number_prefix])
    end

    post "/parts" do
      # Check parameter existence and format.
      halt(400, "Missing project ID.") if params[:project_id].nil? || params[:project_id] !~ /^\d+$/
      halt(400, "Missing part type.") if params[:type].nil?
      halt(400, "Invalid part type.") unless ["part", "assembly"].include?(params[:type])
      halt(400, "Missing part name.") if params[:name].nil?
      if params[:parent_part_number] && params[:parent_part_number] !~ /^\d+$/
        halt(400, "Invalid parent part number.")
      end

      project = Project[params[:project_id].to_i]
      halt(400, "Invalid project.") if project.nil?

      parent_part = nil
      if params[:parent_part_number]
        parent_part = Part[:part_number => params[:parent_part_number].to_i, :project_id => project.id,
                           :type => "assembly"]
        halt(400, "Invalid parent part.") if parent_part.nil?
      end

      Part.generate_number_and_create(project, params[:type], params[:name], parent_part, params[:notes])
    end

    post "/users" do
      halt(400, "Missing email.") if params[:email].nil?
      halt(400, "Missing password.") if params[:password].nil?
      halt(400, "Missing permission.") if params[:permission].nil?
      halt(400, "Invalid permission.") unless ["readonly", "editor", "admin"].include?(params[:permission])
      User.secure_create(params[:email], params[:password], params[:permission])
    end
  end
end
