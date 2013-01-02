# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# The main class of the parts management web server.

require "dedent"
require "eventmachine"
require "pathological"
require "pony"
require "sinatra/base"

require "models"

module CheesyParts
  class Server < Sinatra::Base
    PART_TYPES = ["part", "assembly"]

    set :sessions => true

    before do
      @user = User[session[:user_id]]
      authenticate! unless ["/login", "/register"].include?(request.path)
    end

    def authenticate!
      redirect "/login?redirect=#{request.path}" if @user.nil?
      if @user.enabled == 0
        session[:user_id] = nil
        redirect "/login?disabled=1"
      end
    end

    def require_permission(user_permitted)
      halt(400, "Insufficient permissions.") unless user_permitted
    end

    # Helper function to send an e-mail through Gmail's SMTP server.
    def send_email(to, subject, body)
      # Run this asynchronously using EventMachine since it takes a couple of seconds.
      EM.defer do
        Pony.mail(:from => "Team 254 Part Management System <cheesyparts@gmail.com>", :to => to,
                  :subject => subject, :body => body, :via => :smtp,
                  :via_options => { :address => "smtp.gmail.com", :port => "587",
                                    :enable_starttls_auto => true, :user_name => "cheesyparts",
                                    :password => "254skyf1r3", :authentication => :plain,
                                    :domain => "localhost.localdomain" })
      end
    end

    get "/" do
      redirect "/projects"
    end

    get "/login" do
      redirect "/logout" if @user
      if params[:failed] == "1"
        @alert = "Invalid e-mail address or password."
      elsif params[:disabled] == "1"
        @alert = "Your account is currently disabled."
      end
      @redirect = params[:redirect] || "/"
      erb :login
    end

    post "/login" do
      user = User.authenticate(params[:email], params[:password])
      redirect "/login?failed=1" if user.nil?
      redirect "/login?disabled=1" if user.enabled == 0
      session[:user_id] = user.id
      redirect params[:redirect]
    end

    get "/logout" do
      session[:user_id] = nil
      redirect "/"
    end

    get "/new_project" do
      require_permission(@user.can_administer?)
      erb :new_project
    end

    get "/projects" do
      erb :projects
    end

    post "/projects" do
      require_permission(@user.can_administer?)

      # Check parameter existence and format.
      halt(400, "Missing project name.") if params[:name].nil?
      halt(400, "Missing part number prefix.") if params[:part_number_prefix].nil?

      project = Project.create(:name => params[:name], :part_number_prefix => params[:part_number_prefix])
      redirect "/projects/#{project.id}"
    end

    get "/projects/:id" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :project
    end

    get "/projects/:id/edit" do
      require_permission(@user.can_administer?)

      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :project_edit
    end

    post "/projects/:id/edit" do
      require_permission(@user.can_administer?)

      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      @project.name = params[:name] if params[:name]
      if params[:part_number_prefix]
        @project.part_number_prefix = params[:part_number_prefix]
      end
      @project.save
      redirect "/projects/#{params[:id]}"
    end

    get "/projects/:id/delete" do
      require_permission(@user.can_administer?)

      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :project_delete
    end

    post "/projects/:id/delete" do
      require_permission(@user.can_administer?)

      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      @project.delete
      redirect "/projects"
    end

    get "/projects/:id/dashboard" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      erb :dashboard
    end

    get "/projects/:id/dashboard/parts" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      @status = params[:status] if Part::STATUS_MAP.has_key?(params[:status])
      erb :dashboard_parts
    end

    get "/projects/:id/new_part" do
      require_permission(@user.can_edit?)

      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
      @parent_part_id = params[:parent_part_id]
      @type = params[:type] || "part"
      halt(400, "Invalid part type.") unless PART_TYPES.include?(@type)
      erb :new_part
    end

    get "/dashboards" do
      erb :dashboards
    end

    post "/parts" do
      require_permission(@user.can_edit?)

      # Check parameter existence and format.
      halt(400, "Missing project ID.") if params[:project_id].nil? || params[:project_id] !~ /^\d+$/
      halt(400, "Missing part type.") if params[:type].nil?
      halt(400, "Invalid part type.") unless PART_TYPES.include?(params[:type])
      halt(400, "Missing part name.") if params[:name].nil?
      if params[:parent_part_id] && params[:parent_part_id] !~ /^\d+$/
        halt(400, "Invalid parent part ID.")
      end

      project = Project[params[:project_id].to_i]
      halt(400, "Invalid project.") if project.nil?

      parent_part = nil
      if params[:parent_part_id]
        parent_part = Part[:id => params[:parent_part_id].to_i, :project_id => project.id,
                           :type => "assembly"]
        halt(400, "Invalid parent part.") if parent_part.nil?
      end

      part = Part.generate_number_and_create(project, params[:type], parent_part)
      part.name = params[:name]
      part.status = "designing"
      part.priority = 1;
      part.save
      redirect "/parts/#{part.id}"
    end

    get "/parts/:id" do
      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      erb :part
    end

    get "/parts/:id/edit" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      erb :part_edit
    end

    post "/parts/:id/edit" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      @part.name = params[:name] if params[:name]
      if params[:status]
        halt(400, "Invalid status.") unless Part::STATUS_MAP.include?(params[:status])
        @part.status = params[:status]
      end
      @part.notes = params[:notes] if params[:notes]
      @part.source_material = params[:source_material] if params[:source_material]
      @part.have_material = (params[:have_material] == "on") ? 1 : 0
      @part.cut_length = params[:cut_length] if params[:cut_length]
      @part.quantity = params[:quantity] if params[:quantity]
      @part.drawing_created = (params[:drawing_created] == "on") ? 1 : 0
      @part.priority = params[:priority] if params[:priority]
      @part.save
      redirect "/parts/#{params[:id]}"
    end

    get "/parts/:id/delete" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      erb :part_delete
    end

    post "/parts/:id/delete" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      project_id = @part.project_id
      halt(400, "Invalid part.") if @part.nil?
      halt(400, "Can't delete assembly with existing children.") unless @part.child_parts.empty?
      @part.delete
      redirect "/projects/#{project_id}"
    end

    get "/new_user" do
      require_permission(@user.can_administer?)
      @admin_new_user = true
      erb :new_user
    end

    get "/users" do
      require_permission(@user.can_administer?)
      erb :users
    end

    post "/users" do
      require_permission(@user.can_administer?)

      halt(400, "Missing email.") if params[:email].nil? || params[:email].empty?
      halt(400, "Invalid email.") unless params[:email] =~ /^\S+@\S+\.\S+$/
      halt(400, "User #{params[:email]} already exists.") if User[:email => params[:email]]
      halt(400, "Missing first name.") if params[:first_name].nil? || params[:first_name].empty?
      halt(400, "Missing last name.") if params[:last_name].nil? || params[:last_name].empty?
      halt(400, "Missing password.") if params[:password].nil? || params[:password].empty?
      halt(400, "Missing permission.") if params[:permission].nil? || params[:permission].empty?
      halt(400, "Invalid permission.") unless User::PERMISSION_MAP.include?(params[:permission])
      user = User.new(:email => params[:email], :first_name => params[:first_name],
                      :last_name => params[:last_name], :permission => params[:permission],
                      :enabled => (params[:enabled] == "on") ? 1 : 0)
      user.set_password(params[:password])
      user.save
      redirect "/users"
    end

    get "/users/:id/edit" do
      require_permission(@user.can_administer?)

      @user_edit = User[params[:id]]
      halt(400, "Invalid user.") if @user_edit.nil?
      erb :user_edit
    end

    post "/users/:id/edit" do
      require_permission(@user.can_administer?)

      @user_edit = User[params[:id]]
      halt(400, "Invalid user.") if @user_edit.nil?
      @user_edit.email = params[:email] if params[:email]
      @user_edit.first_name = params[:first_name] if params[:first_name]
      @user_edit.last_name = params[:last_name] if params[:last_name]
      @user_edit.set_password(params[:password]) if params[:password] && !params[:password].empty?
      @user_edit.permission = params[:permission] if params[:permission]
      old_enabled = @user_edit.enabled
      @user_edit.enabled = (params[:enabled] == "on") ? 1 : 0
      if @user_edit.enabled == 1 && old_enabled == 0
        email_body = <<-EOS.dedent
          Hello #{@user_edit.first_name},

          Your account on the Team 254 Parts Management System has been approved.
          You can log into the system at http://parts.team254.com.

          Cheers,

          The Cheesy Parts Robot
        EOS
        send_email(@user_edit.email, "Account approved", email_body)
      end
      @user_edit.save
      redirect "/users"
    end

    get "/users/:id/delete" do
      require_permission(@user.can_administer?)

      @user_delete = User[params[:id]]
      halt(400, "Invalid user.") if @user_delete.nil?
      erb :user_delete
    end

    post "/users/:id/delete" do
      require_permission(@user.can_administer?)

      @user_delete = User[params[:id]]
      halt(400, "Invalid user.") if @user_delete.nil?
      @user_delete.delete
      redirect "/users"
    end

    get "/change_password" do
      erb :change_password
    end

    post "/change_password" do
      halt(400, "Missing password.") if params[:password].nil? || params[:password].empty?
      halt(400, "Invalid old password.") unless User.authenticate(@user.email, params[:old_password])
      @user.set_password(params[:password])
      @user.save
      redirect "/"
    end

    get "/register" do
      @admin_new_user = false
      erb :new_user
    end

    post "/register" do
      halt(400, "Missing email.") if params[:email].nil? || params[:email].empty?
      halt(400, "Invalid email.") unless params[:email] =~ /^\S+@\S+\.\S+$/
      halt(400, "User #{params[:email]} already exists.") if User[:email => params[:email]]
      halt(400, "Missing first name.") if params[:first_name].nil? || params[:first_name].empty?
      halt(400, "Missing last name.") if params[:last_name].nil? || params[:last_name].empty?
      halt(400, "Missing password.") if params[:password].nil? || params[:password].empty?
      user = User.new(:email => params[:email], :first_name => params[:first_name],
                      :last_name => params[:last_name], :permission => "readonly",
                      :enabled => 0)
      user.set_password(params[:password])
      user.save
      email_body = <<-EOS.dedent
        Hello,

        This is a notification that #{user.first_name} #{user.last_name} has created an account on the Team
        254 Parts Management System and it is disabled pending approval.
        Please visit the user control panel at http://parts.team254.com/users to take action.

        Cheers,

        The Cheesy Parts Robot
      EOS
      send_email("cheesyparts@gmail.com", "Approval needed for #{user.email}", email_body)
      erb :register_confirmation
    end
  end
end
