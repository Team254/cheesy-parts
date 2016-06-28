# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# The main class of the parts management web server.

require "active_support/time"
require "cgi"
require "dedent"
require "eventmachine"
require "json"
require "pathological"
require "pony"
require "sinatra/base"

require "models"

module CheesyParts
  class Server < Sinatra::Base
    use Rack::Session::Cookie, :key => "rack.session", :expire_after => 3600

    # Enforce authentication for all routes except login and user registration.
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
        Pony.mail(:from => "Cheesy Parts <#{CheesyCommon::Config.gmail_user}>", :to => to,
                  :subject => subject, :body => body, :via => :smtp,
                  :via_options => { :address => "smtp.gmail.com", :port => "587",
                                    :enable_starttls_auto => true,
                                    :user_name => CheesyCommon::Config.gmail_user.split("@").first,
                                    :password => CheesyCommon::Config.gmail_password,
                                    :authentication => :plain, :domain => "localhost.localdomain" })
      end
    end

    get "/" do
      redirect "/projects"
    end

    get "/login" do
      redirect "/logout" if @user
      @redirect = params[:redirect] || "/"

      if CheesyCommon::Config.enable_wordpress_auth
        member = CheesyCommon::Auth.get_user(request)
        if member.nil?
          redirect "#{CheesyCommon::Config.members_url}?site=parts&path=#{request.path}"
        else
          user = User[:wordpress_user_id => member.id]
          unless user
            user = User.create(:wordpress_user_id => member.id, :first_name => member.name[1],
                               :last_name => member.name[0], :permission => "editor", :enabled => 1,
                               :email => member.email, :password => "", :salt => "")
          end
          session[:user_id] = user.id
          redirect @redirect
        end
      end

      if params[:failed] == "1"
        @alert = "Invalid e-mail address or password."
      elsif params[:disabled] == "1"
        @alert = "Your account is currently disabled."
      end
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
      if CheesyCommon::Config.enable_wordpress_auth
        redirect "#{CheesyCommon::Config.members_url}/logout"
      else
        redirect "/login"
      end
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

    before "/projects/:id*" do
      @project = Project[params[:id]]
      halt(400, "Invalid project.") if @project.nil?
    end

    get "/projects/:id" do
      if ["type", "name", "parent_part_id", "status"].include?(params[:sort])
        @part_sort = params[:sort].to_sym
      else
        @part_sort = :id
      end
      erb :project
    end

    get "/projects/:id/edit" do
      require_permission(@user.can_administer?)

      erb :project_edit
    end

    post "/projects/:id/edit" do
      require_permission(@user.can_administer?)

      @project.name = params[:name] if params[:name]
      if params[:part_number_prefix]
        @project.part_number_prefix = params[:part_number_prefix]
      end
      @project.save
      redirect "/projects/#{params[:id]}"
    end

    get "/projects/:id/delete" do
      require_permission(@user.can_administer?)

      erb :project_delete
    end

    post "/projects/:id/delete" do
      require_permission(@user.can_administer?)

      @project.delete
      redirect "/projects"
    end

    get "/projects/:id/dashboard" do
      erb :dashboard
    end

    get "/projects/:id/dashboard/parts" do
      @status = params[:status] if Part::STATUS_MAP.has_key?(params[:status])
      erb :dashboard_parts
    end

    get "/projects/:id/new_part" do
      require_permission(@user.can_edit?)

      @parent_part_id = params[:parent_part_id]
      @type = params[:type] || "part"
      halt(400, "Invalid part type.") unless Part::PART_TYPES.include?(@type)
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
      halt(400, "Invalid part type.") unless Part::PART_TYPES.include?(params[:type])
      halt(400, "Missing part name.") if params[:name].nil? || params[:name].empty?
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
      part.name = params[:name].gsub("\"", "&quot;")
      part.status = "designing"
      part.source_material = ""
      part.have_material = 0
      part.quantity = ""
      part.cut_length = ""
      part.priority = 1
      part.drawing_created = 0
      part.save
      redirect "/parts/#{part.id}"
    end

    get "/parts/:id" do
      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      if ["type", "name", "parent_part_id", "status"].include?(params[:sort])
        @part_sort = params[:sort].to_sym
      else
        @part_sort = :id
      end
      erb :part
    end

    get "/parts/:id/edit" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      @referrer = request.referrer
      erb :part_edit
    end

    post "/parts/:id/edit" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      halt(400, "Missing part name.") if params[:name] && params[:name].empty?
      @part.name = params[:name].gsub("\"", "&quot;") if params[:name]
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
      redirect params[:referrer] || "/parts/#{params[:id]}"
    end

    get "/parts/:id/delete" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      halt(400, "Invalid part.") if @part.nil?
      @referrer = request.referrer
      erb :part_delete
    end

    post "/parts/:id/delete" do
      require_permission(@user.can_edit?)

      @part = Part[params[:id]]
      project_id = @part.project_id
      halt(400, "Invalid part.") if @part.nil?
      halt(400, "Can't delete assembly with existing children.") unless @part.child_parts.empty?
      @part.delete
      params[:referrer] = nil if params[:referrer] =~ /\/parts\/#{params[:id]}$/
      redirect params[:referrer] || "/projects/#{project_id}"
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

          Your account on Cheesy Parts has been approved.
          You can log into the system at #{URL}.

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

        This is a notification that #{user.first_name} #{user.last_name} has created an account on Cheesy
        Parts and it is disabled pending approval.
        Please visit the user control panel at #{URL}/users to take action.

        Cheers,

        The Cheesy Parts Robot
      EOS
      send_email(CheesyCommon::Config.gmail_user, "Approval needed for #{user.email}", email_body)
      erb :register_confirmation
    end

    get "/orders" do
      erb :orders_project_list
    end

    get "/projects/:id/orders/open" do
      @no_vendor_order_items = OrderItem.where(:order_id => nil, :project_id => params[:id])
      @vendor_orders = Order.filter(:status => "open").where(:project_id => params[:id]).
          order(:vendor_name, :ordered_at)
      @show_new_item_form = params[:new_item] == "true"
      erb :open_orders
    end

    get "/projects/:id/orders/ordered" do
      @vendor_orders = Order.filter(:status => "ordered").where(:project_id => params[:id]).
          order(:vendor_name, :ordered_at)
      erb :completed_orders
    end

    get "/projects/:id/orders/complete" do
      @vendor_orders = Order.filter(:status => "received").where(:project_id => params[:id]).
          order(:vendor_name, :ordered_at)
      erb :completed_orders
    end

    get "/projects/:id/orders/all" do
      @vendor_orders = Order.where(:project_id => params[:id]).order(:vendor_name, :ordered_at)
      if params[:filter]
        key, value = params[:filter].split(":")
        @vendor_orders = @vendor_orders.filter(key.to_sym => value)
      end
      erb :completed_orders
    end

    get "/projects/:id/orders/stats" do
      @orders = Order.filter(:status => "open").invert.where(:project_id => params[:id]).all
      @orders_by_vendor = @orders.inject({}) do |map, order|
        map[order.vendor_name] ||= []
        map[order.vendor_name] << order
        map
      end

      @orders_by_purchaser = @orders.inject({}) do |map, order|
        map[order.paid_for_by] ||= {}
        map[order.paid_for_by][:reimbursed] ||= 0
        map[order.paid_for_by][:outstanding] ||= 0
        if order.reimbursed == 1
          map[order.paid_for_by][:reimbursed] += order.total_cost
        else
          map[order.paid_for_by][:outstanding] += order.total_cost
        end
        map
      end

      erb :order_stats
    end

    post "/projects/:id/order_items" do
      require_permission(@user.can_edit?)

      # Match vendor to an existing open order or create it if there isn't one.
      if params[:vendor].nil? || params[:vendor].empty?
        order_id = nil
      else
        order = Order.where(:project_id => @project.id, :vendor_name => params[:vendor],
                            :status => "open").first
        if order.nil?
          order = Order.create(:project => @project, :vendor_name => params[:vendor], :status => "open")
        end
        order_id = order.id
      end

      OrderItem.create(:project => @project, :order_id => order_id, :quantity => params[:quantity].to_i,
                       :part_number => params[:part_number], :description => params[:description],
                       :unit_cost => params[:unit_cost].to_f, :notes => params[:notes])
      redirect "/projects/#{@project.id}/orders/open"
    end

    get "/projects/:project_id/order_items/:id/editable" do
      require_permission(@user.can_edit?)

      @item = OrderItem[params[:id]]
      halt(400, "Invalid order item.") if @item.nil?
      erb :edit_order_item
    end

    post "/projects/:project_id/order_items/edit" do
      require_permission(@user.can_edit?)

      @item = OrderItem[params[:order_item_id]]
      halt(400, "Invalid order item.") if @item.nil?

      # Handle a vendor change.
      order_id = @item.order.id rescue nil
      old_vendor = @item.order.vendor_name rescue ""
      new_vendor = params[:vendor]
      unless old_vendor == new_vendor
        order = Order.where(:project_id => @project.id, :vendor_name => params[:vendor],
                            :status => "open").first
        if order.nil?
          order = Order.create(:project => @project, :vendor_name => params[:vendor], :status => "open")
        end
        order_id = order.id
      end

      @item.update(:order_id => order_id, :quantity => params[:quantity].to_i,
                   :part_number => params[:part_number], :description => params[:description],
                   :unit_cost => params[:unit_cost].gsub(/\$/, "").to_f, :notes => params[:notes])
      redirect params[:referrer]
    end

    get "/projects/:project_id/order_items/:id/delete" do
      require_permission(@user.can_edit?)

      @item = OrderItem[params[:id]]
      halt(400, "Invalid order item.") if @item.nil?
      @referrer = request.referrer
      erb :order_item_delete
    end

    post "/projects/:project_id/order_items/:id/delete" do
      require_permission(@user.can_edit?)

      @item = OrderItem[params[:id]]
      halt(400, "Invalid order item.") if @item.nil?
      @item.delete
      redirect params[:referrer]
    end

    get "/projects/:id/orders/:order_id" do
      @order = Order[params[:order_id]]
      halt(400, "Invalid order.") if @order.nil?
      erb :order
    end

    post "/projects/:id/orders/:order_id/edit" do
      require_permission(@user.can_edit?)

      @order = Order[params[:order_id]]
      halt(400, "Invalid order.") if @order.nil?
      @order.update(:status => params[:status], :ordered_at => params[:ordered_at],
                    :paid_for_by => params[:paid_for_by], :tax_cost => params[:tax_cost].gsub(/\$/, ""),
                    :shipping_cost => params[:shipping_cost].gsub(/\$/, ""), :notes => params[:notes],
                    :reimbursed => params[:reimbursed] ? 1 : 0)
      redirect "/projects/#{@project.id}/orders/#{@order.id}"
    end

    get "/projects/:id/orders/:order_id/delete" do
      require_permission(@user.can_edit?)

      @order = Order[params[:order_id]]
      halt(400, "Invalid order.") if @order.nil?
      halt(400, "Can't delete a non-empty order.") unless @order.order_items.empty?
      erb :order_delete
    end

    post "/projects/:id/orders/:order_id/delete" do
      require_permission(@user.can_edit?)

      @order = Order[params[:order_id]]
      halt(400, "Invalid order.") if @order.nil?
      halt(400, "Can't delete a non-empty order.") unless @order.order_items.empty?
      @order.delete
      redirect "/orders"
    end
  end
end
