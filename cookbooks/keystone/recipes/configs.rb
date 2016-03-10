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

keystone_etc_dir = "#{node['source_root']}/keystone/etc"

if node['keystone_bootstrap'] then
  # Setup for keystone_bootstrap
  template "#{keystone_etc_dir}/keystone.conf" do
    source "keystone.conf.erb"
    owner 'vagrant'
    group 'vagrant'
    mode '0644'
    variables({
      :keystone_db_dir => keystone_etc_dir
    })
  end
else
  # Copy from sample file
  execute "keystone-configuring" do
    command "cp #{keystone_etc_dir}/keystone.conf.sample #{keystone_etc_dir}/keystone.conf"
    not_if { File.exists?("#{keystone_etc_dir}/keystone.conf")}
  end
end

bash 'set_cron' do
  user "root"
  code <<-EOC
    (crontab -l -u keystone 2>&1 | grep -q token_flush) || echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' /var/spool/cron/crontabs/keystone
  EOC
  not_if "grep '@hourly' /var/spool/cron/crontabs/keystone"
end

