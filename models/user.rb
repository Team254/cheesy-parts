# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a user account on the system.

require "base64"
require "openssl"

class User < Sequel::Model
  PBKDF2_ITERATIONS = 1000
  HASH_BYTES = 24
  SALT_BYTES = 24

  # Creates a database record for the given user after salting and hashing the password. Returns the new user
  # object.
  def self.secure_create(email, password, permission)
    salt = SecureRandom.base64(SALT_BYTES)
    hashed_password = Base64.encode64(OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, salt, PBKDF2_ITERATIONS,
                                                                       HASH_BYTES))
    
    User.create(:email => email, :password => hashed_password, :salt => salt, :permission => permission)
  end

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

  # Recomputes the password hash given a new password.
  def change_password(new_password)
    self.password = Base64.encode64(OpenSSL::PKCS5::pbkdf2_hmac_sha1(new_password, salt, PBKDF2_ITERATIONS,
                                                                     HASH_BYTES))
  end
end
