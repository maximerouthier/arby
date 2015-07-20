#!/bin/bash

# Run this script to get irb started with aRby already initialized (i.e., the
# arby/arby library is already required).

# Execute the irb command in the context of the bundle, making all gems
# specified in the Gemfile available to require in irb.
# The -I option adds the directory lib to the load-path variable.
# The -r option loads the libraries bundler/setup and arby/arby using require.
# The bundler/setup library makes sure that the Ruby program can see the gems in
# the bundle. Normally, we shouldn't need to do this step because the bundle
# exec command sets the $RUBYOPT environment variable to -rbundler/setup, which
# requires the library before executing the Ruby program. But because the 
# arby/arby library is also required with the -r switch, we need to make sure
# that bundler/setup get required first.
bundle exec irb -I'lib' -r'bundler/setup' -r'arby/arby'
