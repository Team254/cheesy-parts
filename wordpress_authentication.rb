# Copyright 2013 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)

require "httparty"
require "pathological"

require "config/environment"

module CheesyParts
  # Helper mixin for third-party authentication using Wordpress.
  module WordpressAuthentication
    # Returns a hash of user info if logged in to Wordpress, or nil otherwise.
    def get_wordpress_user_info
      wordpress_cookie = request.cookies["wordpress_logged_in_3d42b000d2a4a2d18a5508d8ef1e38e4"]
      if wordpress_cookie
        response = HTTParty.get("#{WORDPRESS_AUTH_URL}?cookie=#{URI.encode(wordpress_cookie)}")
        return JSON.parse(response.body) if response.code == 200
      end
      return nil
    end
  end
end
