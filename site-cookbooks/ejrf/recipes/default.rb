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

package "locales" do
  action :install
end

locale = "en_US.UTF-8"

ruby_block "Set locale for this session" do
    block do
        ENV["LANG"] = locale 
        ENV["LC_ALL"] = locale 
    end
end

execute "Set locale permanently" do
    command "update-locale LANG=#{locale} LC_ALL=#{locale}"
end

execute "Set timezone" do
    command 'echo "Etc/UTC" > /etc/timezone'
end

execute 'update system' do
   command 'sudo apt-get update'
   action :run
end

%w{ build-essential python-virtualenv python2.7-dev python-pip python-setuptools libpq-dev libxml2 libxml2-dev libxslt1-dev }.each do |pkg|
    package pkg do
	action :install
    end
end

user node["user"]["name"] do
    action :create
    username node["user"]["name"]
    password node["user"]["password"]
    home "/home/#{node["user"]["name"]}"

end

directory "/home/#{node["user"]["name"]}/app" do
    owner node["user"]["name"]
    mode 00755
    action :create
    recursive true
end

execute " make sure user owns his home directory" do
    command "chown -R #{node["user"]["name"]} /home/#{node["user"]["name"]} "
    action :run
end


git "/home/#{node["user"]["name"]}/app" do
    repository node[:application][:repo]
    destination "/home/#{node["user"]["name"]}/app/src"
    action :sync
end

execute "setup virtualenv for application" do
    command "virtualenv --no-site-packages /home/#{node["user"]["name"]}/app/venv/"
    action :run
end

execute "install pip requirements" do
    cwd "/home/#{node["user"]["name"]}/app/src"
    command "bash -c 'source /home/#{node["user"]["name"]}/app/venv/bin/activate && pip install -r pip-requirements.txt'"
end

%w{libmemcached-dev libpq-dev postgresql-contrib-9.1 libsasl2-dev libcloog-ppl-dev libcloog-ppl0 }.each do |pkg|
		package pkg
end

package 'postgresql-9.1' do
  action :install
end

directory '/etc/postgresql/9.1/main' do
   owner 'postgres'
   group 'postgres'
   mode 0700
   recursive true
   action :create
 end

template "/etc/postgresql/9.1/main/pg_hba.conf" do
  user "postgres"
  source "pg_hba.conf.erb"
end

template "/etc/postgresql/9.1/main/postgresql.conf" do
  user "postgres"
  source "postgresql.conf.erb"
end

directory '/var/lib/postgresql/9.1/main' do
   owner 'postgres'
   group 'postgres'
   mode 0700
   recursive true
   action :create
 end


execute  "create postgres socket" do
   command "touch /var/run/postgresql/.s.PGSQL.5432" 
end 

service 'postgresql' do
  action :restart
end

execute "create-database-user" do
    code = "psql -U #{node["user"]["name"]} -c \"select * from pg_user where usename='#{node["user"]["name"]}'\" | grep -c #{node["user"]["name"]}"
    command "createuser -h localhost -U postgres -sw #{node["user"]["name"]}"
    not_if code 
end

execute "create-database" do
    exists = "psql -U #{node["user"]["name"]} -c \"select * from pg_user where usename='#{node["user"]["name"]}'\" | grep -c #{node["user"]["name"]}"
    command "createdb -h localhost -U #{node["user"]["name"]} -O #{node["user"]["name"]} -E utf8 -T template0 #{node["user"]["name"]}"
    not_if exists
end


execute "syncdb " do
    user "ejrf"
    cwd "/home/#{node["user"]["name"]}/app/src/"
    command "bash -c 'source /home/#{node["user"]["name"]}/app/venv/bin/activate && python manage.py syncdb --noinput '"
    action :run
end
execute "migrate " do
    user "ejrf"
    cwd "/home/#{node["user"]["name"]}/app/src/"
    command "bash -c 'source /home/#{node["user"]["name"]}/app/venv/bin/activate && python manage.py migrate '"
    action :run
end

package 'nginx' do
  action :install
end

template "/etc/nginx/nginx.conf" do
  source "nginx.conf.erb"
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

template "/etc/uwsgi/apps-available/#{node["user"]["name"]}.ini" do
	source 'wsgi_app_conf.ini.erb'
  variables ({:app => node["app"]["name"],:venv => "/home/#{node["user"]["name"]}/app/venv",:project => "/home/#{node["user"]["name"]}/app/src/"})
end

template "/etc/nginx/sites-available/#{node["user"]["name"]}" do
    action :create
    source "nginx-app.conf.erb"
    variables ({:sock => "tmp/#{node["app"]["name"]}.sock",:app => "/home/#{node["user"]["name"]}/app/src",:name => node["user"]["name"]})
end

link "/etc/uwsgi/apps-enabled/#{node["user"]["name"]}.ini" do
    to "/etc/uwsgi/apps-available/#{node["user"]["name"]}.ini"
end

link "/etc/nginx/sites-enabled/#{node["user"]["name"]}" do
    to "/etc/nginx/sites-available/#{node["user"]["name"]}"
end

execute  "restart uwsgi" do
    action :run
    command "sudo service uwsgi restart"
end

execute  "touch app reload " do
    action :run
    command "touch /home/#{node["user"]["name"]}/app/src/#{node["app"]["name"]}/reload"
end


service 'nginx' do
  action :restart
end

execute  "restart uwsgi" do
    action :run
    command "sudo service uwsgi restart"
end
