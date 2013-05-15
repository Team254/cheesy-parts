Cheesy Parts
============

Cheesy Parts is a web-based system for tracking parts through the design and manufacture cycle. It assigns
part numbers according to a common scheme, with which CAD files can be saved to version control, and stores
information about the part's current manufacturing status.

Cheesy Parts is written in Ruby using the (http://sinatrarb.com)[Sinatra] framework, and uses MySQL as the
backing datastore.

## Development

Prerequisites:

* Ruby 1.9 (1.9.3-p286 is used in development and production)
* (http://gembundler.com)[Bundler]
* MySQL

To run Cheesy Parts locally, use the following procedure:

1. Create an empty MySQL database and a user account with full permissions on it
1. Populate config/environment.rb with the parameters for the development environment. This file is
overwritten on deploy with the parameters in the Rakefile, so it's okay to set the development values in it
and then forget about it.
1. Run `bundle install`. This will download and install the gems that Cheesy Parts depends on.
1. Run `bundle exec rake db:migrate`. This will run the database migrations to create the necessary tables in
MySQL.
1. Run `ruby parts_server_control.rb <command>` to control the running of the Cheesy Parts server, where
<command> can be one of start|stop|run|restart.

## Deployment

The Cheesy Parts codebase includes (https://github.com/dmacdougall/fezzik)[Fezzik] scripts for deploying to
a remote server via SSH.

1. Set up the remote server with the same prerequisites and procedure as for development.
1. Set up the remote server for password-less (public-key) login.
1. Fill in the hostname, database credentials and other parameters in the Rakefile.
1. Run `bundle exec fez prod deploy`.

This last command will create the remote directory structure, copy the code over, install the necessary gems,
run the database migrations, and start the server on the port specified in the Rakefile.

## Contributing

If you have a suggestion for a new feature, create an issue or shoot an e-mail to
[pat@patfairbank.com](mailto:pat@patfairbank.com). Or if you have some Ruby-fu and are feeling adventurous,
fork this project and send a pull request.
