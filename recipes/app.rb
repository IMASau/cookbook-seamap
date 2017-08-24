#
# Cookbook Name:: imas_seamap
# Recipe:: app
#
# Copyright 2017, IMAS
#
# All rights reserved - Do Not Redistribute
#

# Install the front-end components.  It requires you to compile it
# yourself, and place it inside the files directory (a symlink should
# work)


base_dir = node['seamap']['client']['deploydir']

remote_directory base_dir do
  source 'frontend' # symlink the seamap frontend resources/public directory to <cookbook>/files/default/frontend
  mode '0755'
  files_mode '0444'
end
