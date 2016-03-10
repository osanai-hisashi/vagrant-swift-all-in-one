# Copyright (c) 2016 Fujitsu, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require "mixlib/shellout"

keystone_etc_dir = "#{node['source_root']}/keystone/etc"

# Create identity database
execute "populate_identity_service" do
  command '/usr/local/bin/keystone-manage db_sync'
  cwd keystone_etc_dir
  not_if { File.exists?("#{keystone_etc_dir}/keystone.db")}
end

if node['keystone_bootstrap'] then
  os_bootstrap_username ="admin_token_user"
  os_bootstrap_password = "admin_token_user_password"
  os_bootstrap_project_name = "admin_token_project"
  os_bootstrap_role_name = "admin"
  if node['keystone_bootstrap'] then
    execute "keystone-manage bootstrap" do
      command '/usr/local/bin/keystone-manage bootstrap'
      cwd keystone_etc_dir
      only_if { File.exists?("#{keystone_etc_dir}/keystone.db")}
      environment ({
        "OS_BOOTSTRAP_USERNAME" =>"#{os_bootstrap_username}",
        "OS_BOOTSTRAP_PASSWORD" =>"#{os_bootstrap_password}",
        "OS_BOOTSTRAP_PROJECT_NAME" =>"#{os_bootstrap_project_name}",
        "OS_BOOTSTRAP_ROLE_NAME" =>"#{os_bootstrap_role_name}"
      })
    end
  end
end

execute "keystone-start" do
  command "/usr/local/bin/keystone-all --config-file #{keystone_etc_dir}/keystone.conf --logfile /var/log/keystone.log &"
  cwd "/"
  only_if { File.exists?("#{keystone_etc_dir}/keystone.conf")}
end

execute "wait keystone-start" do
  command "sleep 5s"
end

# Get Token
if node['keystone_bootstrap'] then
  # Get token from keystone bootstrap user
  template "/tmp/get_token.json" do
    source "get_token.json.erb"
    owner 'vagrant'
    group 'vagrant'
    mode '0644'
    variables({
      :domain_name => 'Default',
      :username => "#{os_bootstrap_username}",
      :password => "#{os_bootstrap_password}",
      :project_name => "#{os_bootstrap_project_name}"
    })
  end
end

# Insert keystone initial data
if node['keystone_register_data_method'] == 'curl' then
  cookbook_file '/tmp/register_keystone_initial_data.sh' do
    mode 0744
  end

  execute 'register swift initial data to keystone by curl' do
    command "bash /tmp/register_keystone_initial_data.sh /tmp/get_token.json"
    user "root"
    only_if { File.exists?("#{keystone_etc_dir}/keystone.db")}
  end

  cookbook_file '/tmp/register_keystone_initial_data.sh' do
    action :delete
  end
else
  bash 'register keystone initial data by openstack-client' do
    user "root"
    code <<-EOC
      unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

      # TODO
      # According to Openstack Installation Guide, there is not necessary to
      # create demo project/user but there is a problem if there is no
      # demo project/user creation before admin project/user creation.
      # So I put them for workaround.
      openstack project create --description "Demo Project" demo
      openstack user create --password demo_password demo --email demo@example.com --project demo

      openstack project create --description "Admin Project" admin
      openstack user create --password admin_password admin --email admin@example.com --project admin
      openstack role create admin
      openstack role add --project admin --user admin admin
      openstack project create --description "Service Project" service
      openstack service create --type identity --description "OpenStack Identity" keystone
      openstack endpoint create --publicurl http://127.0.0.1:5000/v2.0  --internalurl http://127.0.0.1:5000/v2.0  --adminurl http://127.0.0.1:35357/v2.0  --region RegionOne keystone

    EOC
    environment "OS_TOKEN" =>"#{token}", "OS_AUTH_URL" =>'http://127.0.0.1:35357/v2.0'
    only_if { File.exists?("#{keystone_etc_dir}/keystone.db")}
  end

  bash 'register swift initial data to keystone' do
    user "root"
    code <<-EOC
      unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
      openstack user create --password swift_password swift --email admin@example.com --project service
      openstack role add --project service --user swift admin
      openstack service create --type object-store --description "OpenStack Object Storage" swift
      openstack endpoint create --publicurl 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s'  --internalurl 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s'  --adminurl 'http://127.0.0.1:8080' --region RegionOne swift
    EOC
    environment "OS_TOKEN" =>"#{token}", "OS_AUTH_URL" =>'http://127.0.0.1:35357/v2.0'
    only_if { File.exists?("#{keystone_etc_dir}/keystone.db")}
  end
end

# For function test data
cookbook_file '/tmp/register_keystone_data.sh' do
  mode 0744
end

execute 'register data to keystone by curl for swift function test' do
  command "bash /tmp/register_keystone_data.sh /tmp/get_token.json"
  user "root"
  only_if { File.exists?("#{keystone_etc_dir}/keystone.db")}
end

cookbook_file '/tmp/register_keystone_data.sh' do
  action :delete
end

