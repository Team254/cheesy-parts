Cheesy Parts
============

Cheesy Parts is a web-based system for tracking parts through the design and manufacture cycle. It assigns
part numbers with which CAD files can be saved to version control and stores information about parts'
current manufacturing status.

Cheesy Parts is written in Ruby using the [Sinatra](http://sinatrarb.com) framework and uses MySQL as the
backing datastore. Development and production are run on UNIX (OS X and Ubuntu), so there are no guarantees
it'll work on Windows, sorry.

## Development

Prerequisites:

* Ruby 1.9 (1.9.3-p286 is what we use in development and production)
* [Bundler](http://gembundler.com)
* MySQL

To run Cheesy Parts locally:

1. Create an empty MySQL database and a user account with full permissions on it.
1. Populate `config/environment.rb` with the parameters for the development environment. This file is
overwritten on deploy with the parameters in the Rakefile, so it's okay to set the development values in it
and then forget about it.
1. Run `bundle install`. This will download and install the gems that Cheesy Parts depends on.
1. Run `bundle exec rake db:migrate`. This will run the database migrations to create the necessary tables in
MySQL.
1. Run `ruby parts_server_control.rb <command>` to control the running of the Cheesy Parts server, where
`<command>` can be one of `start`|`stop`|`run`|`restart`.

The database migration will create an admin account (username "deleteme@team254.com", password "chezypofs")
that you can use to first get into the system and create other accounts. It is highly recommended that you
delete this account after having created your own admin account.

## Deployment

The Cheesy Parts codebase includes [Fezzik](https://github.com/dmacdougall/fezzik) scripts for deploying to
a remote server via SSH. To deploy:

1. Set up the remote server with the same prerequisites and procedure as for development.
1. Set up the remote server for password-less (public-key) login.
1. Fill in the hostname, database credentials and other parameters in the Rakefile.
1. Run `bundle exec fez prod deploy`.

This last command will create the remote directory structure, copy the code over, install the necessary gems,
run the database migrations, and start the server on the port specified in the Rakefile.

## Contributing

If you have a suggestion for a new feature, create an issue on GitHub or shoot an e-mail to
[pat@patfairbank.com](mailto:pat@patfairbank.com). Or if you have some Ruby-fu and are feeling adventurous,
fork this project and send a pull request.
