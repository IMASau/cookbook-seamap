#
# Cookbook Name:: imas_seamap
# Recipe:: app
#
# Copyright 2017, IMAS
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'application'
include_recipe 'apache2'

['tdsodbc', 'unixodbc-dev', 'python-dev'].each{ |p| package p }

# Must specify the secret key parameter:
raise unless node['seamap']['secret_key']

admins        = node['seamap']['email']['admins'] || []
allowed_hosts = node['seamap']['allowed_hosts'] || []
appdir        = node['seamap']['deploydir']
database      = node['seamap']['database']
emailfrom     = node['seamap']['email']['from'] || 'IMAS.DataManager@utas.edu.au'
emailhost     = node['seamap']['email']['emailhost']
repository    = node['seamap']['repository']
secret_key    = node['seamap']['secret_key']
urlroot       = node['seamap']['urlroot']
whitelist     = node['seamap']['cors_whitelist'] || []

seamap_repository = Chef::DataBagItem.load('repositories', repository)
deploy_key_name   = seamap_repository['deploy_key']
seamap_deploy_key = Chef::DataBagItem.load('deploy_keys', deploy_key_name)['ssh_priv_key'] if deploy_key_name

directory "/mnt/ebs/#{appdir}"
directory "/mnt/ebs/#{appdir}/shared"
directory "/mnt/ebs/#{appdir}/media"

local_settings = {
  :rootpath       => urlroot,
  :emailhost      => emailhost,
  :admins         => admins,
  :emailfrom      => emailfrom,
  :allowed_hosts  => allowed_hosts,
  :cors_whitelist => whitelist,
  :secret_key     => secret_key
}

application 'Seamap' do
  path "/mnt/ebs/#{appdir}"

  repository seamap_repository['url']
  revision   seamap_repository['revision'] || 'master'
  deploy_key seamap_deploy_key
  rollback_on_error !!(seamap_repository['rollback_on_error'] || false)

  django do
    # debug true
    requirements 'backend/deploy_requirements.txt'
    local_settings_file 'backend/webapp/local_settings.py'
    settings_template 'local_settings.py.erb'
    settings local_settings
    database do
      adapter  'sql_server.pyodbc'
      database database['name']
      username database['username']
      password database['password']
      host     database['host']
    end
  end

  gunicorn do
    app_module 'webapp.wsgi'
    directory "/mnt/ebs/#{appdir}/current/backend"
    virtualenv "/mnt/ebs/#{appdir}/shared/env"
    autostart true
    preload_app true
    port 8092
  end
end


# Configure Apache:
template "/mnt/ebs/#{appdir}/shared/apache.conf" do
  source "apache.conf.erb"
  cookbook "imas_seamap"
  mode "644"
  variables :approot => urlroot, :appdir => "/mnt/ebs/#{appdir}"
  notifies :reload, "service[apache2]", :delayed
end

# Bounce supervisor, just to be safe:
service "supervisor" do
  action :restart
end
