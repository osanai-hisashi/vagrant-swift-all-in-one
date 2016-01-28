# Copyright (c) 2015 Fujitsu, Inc.
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

# ensure source_root
directory "#{node['source_root']}" do
  owner "vagrant"
  group "vagrant"
  action :create
end

### Setup
execute "apt-get-update" do
  command "apt-get update"
  action :run
end

required_packages = [
  "git", "python-dev", "python3-dev", "libxml2-dev", "libxslt1-dev",
  "libsasl2-dev", "libsqlite3-dev", "libssl-dev", "libldap2-dev",
  "libffi-dev", "build-essential", "libxslt-dev",
]
required_packages.each do |pkg|
  package pkg do
    action :install
  end
end

execute "install pip" do
  command "curl https://bootstrap.pypa.io/get-pip.py | python"
  not_if "which pip"
end

execute "upgrade pip" do
  command "pip install --upgrade pip"
  end

execute "git keystone" do
  cwd "#{node['source_root']}"
  command "git clone -b #{node['keystone_repo_branch']} #{node['keystone_repo']}"
  creates "#{node['source_root']}/keystone"
  action :run
end

execute "keystone-install" do
  cwd "#{node['source_root']}/keystone"
  command "pip install -e . && pip install -r test-requirements.txt"
  if not node['full_reprovision']
    creates "/usr/local/lib/python2.7/dist-packages/keystone.egg-link"
  end
  action :run
end

if node['keystone_register_data_method'] != 'curl' then
  execute "git python-openstackclient" do
    cwd "#{node['source_root']}"
    command "git clone -b #{node['openstackclient_repo_branch']} #{node['openstackclient_repo']}"
    creates "#{node['source_root']}/python-openstackclient"
    action :run
  end

  execute "python-openstackclient-install" do
    cwd "#{node['source_root']}/python-openstackclient"
    command "pip install -e . && pip install -r test-requirements.txt"
    if not node['full_reprovision']
      creates "/usr/local/lib/python2.7/dist-packages/python-openstackclient.egg-link"
    end
    action :run
  end
end
