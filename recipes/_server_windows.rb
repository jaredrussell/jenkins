#
# Cookbook Name:: jenkins
# Recipe:: _server_windows
#
# Author:: Jared Russell <jared.s.russell@accenture.com>
# Author:: Sapana Kapri <sapana.kapri@accenture.com>
# Author:: Anju Rani Mathews <anju.rani.mathews@accenture.com>
# Author:: Sandeep Rathod <sandeep.rathod@accenture.com>
#
# Copyright 2013, Accenture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

version = node['jenkins']['server']['version']

if version.nil?
  Chef::Application.fatal!("Jenkins version number must be specified when installing on Windows")
end

home_dir = node['jenkins']['server']['home']
url = node['jenkins']['server']['package_url']
zip_path = File.join(Chef::Config[:file_cache_path], File.basename(url))

remote_file zip_path do
  source url
  checksum node['jenkins']['server']['package_checksum']
end

extract_path = File.join(Chef::Config[:file_cache_path], File.basename(url, ".*"))

windows_zipfile extract_path do
  source zip_path
  not_if { File.exists?(extract_path) }
end

windows_package "Jenkins #{version}" do
  source File.join(extract_path, "jenkins-#{version}.msi")
  installer_type :msi
  options "JENKINSDIR=\"#{home_dir}\""
end

template "#{home_dir}/jenkins.xml" do
  source 'jenkins.xml.erb'
  variables(:http_port => node['jenkins']['server']['port'],
            :prefix => node['jenkins']['server']['prefix']))
  notifies :restart, 'service[jenkins]'
end

service_name = 'Jenkins'
service_account = node['jenkins']['server']['service_user']
#
# The allowed values for account that service can run as are:
# * LocalSystem => Default. Service runs with the machine account.
# * .\Administrator => Local Account.
# * domain\username => Domain Account.
#

# Make sure account name is converted to a local account name if
# needed.
if service_account != 'LocalSystem' && !service_account.include?('\\')
  service_account = ".\\#{service_account}"
end

service_cred_command = "sc config #{service_name} obj= #{service_account}"

# Password is not necessary if the service is running as LocalSystem
if service_account != 'LocalSystem'
  service_cred_command += " password= #{node['jenkins']['server']['service_user_password']}"
end

execute service_cred_command do
  only_if do
    service = WMI::Win32_Service.find(:first, :conditions => { :name => service_name })
    !service.nil? && service.startName != service_account
  end

  notifies :restart, 'service[jenkins]', :immediately
end

service 'jenkins' do
  supports :status => true, :restart => true
  action  [:enable, :start]
end