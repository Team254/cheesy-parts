# Copyright 2013 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)

require "httparty"
require "pathological"
require "json"

require "config"

module CheesyParts
  # Helper mixin for third-party authentication using Wordpress.
  module WordpressAuthentication
    WORDPRESS_AUTH_URL = "http://www.team254.com/auth/"

    def wordpress_cookie
      request.cookies[request.cookies.keys.select { |key| key =~ /wordpress_logged_in_[0-9a-f]{32}/ }.first]
    end

    # Returns a hash of user info if logged in to Wordpress, or nil otherwise.
    def get_wordpress_user_info
      if wordpress_cookie
        response = HTTParty.get("#{WORDPRESS_AUTH_URL}?cookie=#{URI.encode(wordpress_cookie)}")
        return JSON.parse(response.body) if response.code == 200
      end
      return nil
    end
  end
end
