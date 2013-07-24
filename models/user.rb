# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a user account on the system.

require "base64"
require "openssl"
require "securerandom"

class User < Sequel::Model
  PBKDF2_ITERATIONS = 1000
  HASH_BYTES = 24
  SALT_BYTES = 24
  PERMISSION_MAP = { "readonly" => "Read-only", "editor" => "Editor", "admin" => "Administrator" }

  # Checks the given credentials against the database. Returns the user object on success and nil otherwise.
  def self.authenticate(email, password)
    user = User[:email => email]
    if user
      hashed_password = Base64.encode64(OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, user.salt,
                                                                         PBKDF2_ITERATIONS, HASH_BYTES))
      if hashed_password == user.password
        return user
      end
    end
    nil
  end

  # Generates a new salt and computes the password hash for the given password.
  def set_password(new_password)
    self.salt = SecureRandom.base64(SALT_BYTES)
    self.password = Base64.encode64(OpenSSL::PKCS5::pbkdf2_hmac_sha1(new_password, salt, PBKDF2_ITERATIONS,
                                                                     HASH_BYTES))
  end

  def can_edit?
    ["editor", "admin"].include?(self.permission)
  end

  def can_administer?
    self.permission == "admin"
  end
end
