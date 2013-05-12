# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Fezzik tasks for deploying and controlling the parts server.

require "fileutils"

namespace :fezzik do
  desc "stages the project for deployment in /tmp"
  task :stage do
    system("bundle package")
    puts "staging project in /tmp/#{app}"
    FileUtils.rm_rf "/tmp/#{app}"
    FileUtils.mkdir_p "/tmp/#{app}/staged"
    # Use rsync to preserve executability and follow symlinks.
    system("rsync -aqE #{local_path}/. /tmp/#{app}/staged")
    Rake::Task["fezzik:save_environment"].invoke
  end

  desc "performs any necessary setup on the destination servers prior to deployment"
  remote_task :setup do
    puts "setting up servers"
    run "mkdir -p #{deploy_to}/releases"
  end

  desc "rsyncs the project from its staging location to each destination server"
  remote_task :push => [:stage, :setup] do
    puts "pushing to #{target_host}:#{release_path}"
    # Copy on top of previous release to optimize rsync.
    rsync "-q", "--copy-dest=#{current_path}", "/tmp/#{app}/staged/", "#{target_host}:#{release_path}"
  end

  desc "symlinks the latest deployment to /deploy_path/project/current"
  remote_task :symlink do
    puts "symlinking current to #{release_path}"
    run "cd #{deploy_to} && ln -fns #{release_path} current"
  end

  desc "runs the application"
  remote_task :start do
    puts "starting from #{Fezzik::Util.capture_output { run "readlink #{current_path}" }}"
    run "cd #{current_path} && ruby parts_server_control.rb start"
  end

  desc "kills the application"
  remote_task :stop do
    puts "stopping app"
    run "(kill -9 `ps aux | grep 'parts_server' | grep -v grep | awk '{print $2}'` || true)"
  end

  desc "restarts the application"
  remote_task :restart do
    Rake::Task["fezzik:stop"].invoke
    Rake::Task["fezzik:start"].invoke
  end

  desc "full deployment pipeline"
  task :deploy do
    Rake::Task["fezzik:push"].invoke
    Rake::Task["fezzik:symlink"].invoke
    Rake::Task["fezzik:bundle_install"].invoke
    Rake::Task["fezzik:migrate_db"].invoke
    Rake::Task["fezzik:restart"].invoke
    puts "#{app} deployed!"
  end

  desc "installs required gems"
  remote_task :bundle_install do
    puts "bundle installing"
    run "cd #{current_path} && bundle install --local --without test"
  end

  desc "runs database migrations"
  remote_task :migrate_db do
    puts "running database migrations"
    run "cd #{current_path} && rake db:migrate"
  end
end
