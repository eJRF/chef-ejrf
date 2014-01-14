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


user node["user"]["name"] do
    action :create
    username node["user"]["name"]
    password node["user"]["password"]
    home "/home/#{node["user"]["name"]}"
end

directory "/home/#{node["user"]["name"]}/app" do
    owner node["user"]["name"]
    mode 00644
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
    group node["user"]["name"]
    action :sync
end

execute "setup virtualenv for application" do
    command "virtualenv --no-site-packages /home/#{node["user"]["name"]}/app/venv"
    action :run
end

execute "install pip requirements" do
    cwd "/home/#{node["user"]["name"]}/app/src"
    command "bash -c 'source /home/#{node["user"]["name"]}/app/venv/bin/activate && pip install -r pip-requirements.txt'"
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
    psql -h localhost -U postgres -c "select * from pg_user where usename='#{node["user"]["name"]}'" | grep -c #{node["db"]["password"]}
    EOH
    command "createuser -U postgres -h localhost -sw ejrf"
    not_if code 
end

execute "create-database" do
    exists = <<-EOH
    psql -h localhost -U ejrf -c "select * from pg_user where usename='#{node["user"]["name"]}'" | grep -c #{node["db"]["password"]}
    EOH
    command "createdb -U ejrf -h localhost -O ejrf -E utf8 -T template0 #{node["user"]["name"]}"
    not_if exists
end


execute "syncdb " do
    action :run
    command "bash -c 'source /home/#{node["user"]["name"]}/app/venv/bin/activate && python manage.py syncdb --noinput --settings=settings.prod'"
    cwd "/home/#{node["user"]["name"]}/app/src/#{node["user"]["name"]}"
end
execute "migrate " do
    action :run
    command "bash -c 'source /home/#{node["user"]["name"]}/app/venv/bin/activate && python manage.py migrate --settings=settings.prod'"
    cwd "/home/#{node["user"]["name"]}/app/src/#{node["user"]["name"]}"
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
  variables ({:app => node["app"]["name"],:venv => "/home/#{node["user"]["name"]}/app/venv",:project => "/home/#{node["user"]["name"]}/app/src/#{node["user"]["name"]}"})
end

template "/etc/nginx/sites-available/#{node["user"]["name"]}" do
    action :create
    source "nginx-app.conf.erb"
    variables ({:sock => "tmp/#{node["user"]["name"]}.sock",:app => "/home/#{node["user"]["name"]}/app/src/#{node["user"]["name"]}",:name => node["user"]["name"]})
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
    command "touch /home/#{node["user"]["name"]}/app/src/#{node["user"]["name"]}/reload"
end

service 'uwsgi' do
	action :start
end
