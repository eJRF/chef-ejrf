#
# Cookbook Name:: ejrf
# Recipe:: default
#
# Copyright 2013, Unicef Uganda 
#
# All rights reserved - Do Not Redistribute

package 'git' do
   action :install
end

#python dependencies

execute 'update system' do
   command 'sudo apt-get update'
   action :run
end

%w{ build-essential python-dev python-setuptools python-pip libpq-dev libxml2 libxml2-dev libxslt1-dev }.each do |pkg|
    package pkg do
	action :install
    end
end

execute 'Install virtual env' do
  command 'pip install virtualenv'
  action :run
end

execute 'create virtual env' do
  cwd '/home/vagrant'
  command 'virtualenv ejrf_env'
  action :run
end

execute 'owns the ejrf virtualenv' do
  command 'sudo chown vagrant:vagrant /home/vagrant/ejrf_env/ -R'
  action :run
end

git "/vagrant/ejrf/" do
  repository "https://github.com/eJRF/ejrf.git"
  action :sync
end

execute 'copy localsettings.example' do
	cwd '/vagrant/eJRF/'
	command "sudo cp localsettings.py.example localsettings.py"
	action :run
end


%w{libmemcached-dev  libsasl2-dev libcloog-ppl-dev libcloog-ppl0 }.each do |pkg|
		package pkg
end

package 'postgresql' do
  action :install
end

template "/etc/postgresql/9.1/main/pg_hba.conf" do
  user "postgres"
  source "pg_hba.conf.erb"
end

template "/etc/postgresql/9.1/main/postgresql.conf" do
  user "postgres"
  source "postgresql.conf.erb"
end

service "postgresql" do
  action :restart
end

execute "create-root-user" do
    code = <<-EOH
    psql -h localhost -U postgres -c "select * from pg_user where usename='root'" | grep -c root
    EOH
    command "createuser -U postgres -h localhost -s root"
    not_if code 
end
 
execute "create-database-user" do
    code = <<-EOH
    psql -h localhost -U postgres -c "select * from pg_user where usename='ejrf'" | grep -c ejrf
    EOH
    command "createuser -U postgres -h localhost -sw ejrf"
    not_if code 
end

execute "create-database" do
    exists = <<-EOH
    psql -h localhost -U ejrf -c "select * from pg_user where usename='ejrf'" | grep -c ejrf
    EOH
    command "createdb -U ejrf -h localhost -O ejrf -E utf8 -T template0 ejrf"
    not_if exists
end

execute'activating virtual env and installing pip requirements' do
   cwd '/vagrant/'
   command "bash -c 'source /home/vagrant/ejrf_env/bin/activate && pip install -r pip-requirements.txt'"
   action :run
end	

execute "syncdb and run migrations" do
    cwd '/vagrant/'
    command "bash -c 'source /home/vagrant/ejrf_env/bin/activate && python manage.py syncdb --noinput && python manage.py migrate'"
    action :run
end

package 'nginx' do
  action :install
end

template "/etc/nginx/nginx.conf" do
  source "nginx.conf.erb"
end

template "/etc/nginx/conf.d/nginx.conf" do
  source "custom_nginx.conf.erb"
end

service 'nginx' do
  action :restart
end

package 'uwsgi' do
	action :install
end

package 'uwsgi-plugin-python' do
	action :install
end

template '/etc/uwsgi/apps-enabled/ejrf.ini' do
	source 'custom_ejrf_uwsgi.ini.erb'
end

template "/etc/uwsgi/apps-available/ejrf.ini" do
	source 'custom_ejrf_uwsgi.ini.erb'
end

execute 'Delete /var/www/sockets' do
	command 'rm -rf /var/www/sockets'
	action :run
end

execute 'create /var/www/sockets' do
	command 'mkdir -p /var/www/ && mkdir -p /var/www/sockets'
	action :run
end

service 'uwsgi' do
	action :start
end
