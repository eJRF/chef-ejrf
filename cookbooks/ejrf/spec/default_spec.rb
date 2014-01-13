require 'chefspec'

describe 'mics::default' do

  let (:chef_run) { ChefSpec::ChefRunner.new.converge 'mics::default' }

describe 'Install git'do

    it 'installs git package' do
	      expect(chef_run).to install_package 'git'
    end
end

describe 'python and its dependencies' do

    it 'executes apt-get update' do
        expect(chef_run).to execute_command('sudo apt-get update')
    end

   it 'installs python dependencies' do
    ['build-essential',
    'python-dev', 
    'python-setuptools', 
    'python-pip',
    'libpq-dev',
    'libxml2',
    'libxml2-dev',
    'libxslt1-dev']
    .each {|package|
	      expect(chef_run).to install_package package  
      }
   end 

   it 'installs virtual env' do
      expect(chef_run).to execute_command('pip install virtualenv')
   end

   it 'creates the mics virtual env' do
       expect(chef_run).to execute_command('virtualenv mics_env').with(:cwd =>'/home/vagrant')
   end
  
    it 'changes ownership of the virtual env' do
        expect(chef_run).to execute_command('sudo chown vagrant:vagrant /home/vagrant/mics_env/ -R')
    end

end
 
describe 'Mics project configuration' do   
   it 'it activates virtualenv and installs requirements' do
       expect(chef_run).to execute_command("bash -c 'source /home/vagrant/mics_env/bin/activate && pip install -r pip-requires.txt'").with(:cwd =>'/vagrant/mics/')
   end

   it 'syncs the database and runs migrations and 'do
	    command="bash -c 'source /home/vagrant/mics_env/bin/activate && python manage.py syncdb --noinput && python manage.py migrate'"
      expect(chef_run).to execute_command(command).with(:cwd =>'/vagrant/mics/')
   end

   it 'copies investigator configuration 'do
	    command='cp investigator_configs.py.example investigator_configs.py'
      expect(chef_run).to execute_command(command).with(:cwd =>'/vagrant/mics/survey/')
   end

   it 'copies localsettings.example to localsettings'do
	    command='cp localsettings.py.example localsettings.py'
      expect(chef_run).to execute_command(command).with(:cwd =>'/vagrant/mics/mics/')
   end
end

describe "Install lib memcached" do
	it "installs memcache dependencies" do
		memcached_deps = ['libsasl2-dev','libsasl2-dev','libcloog-ppl0','libmemcached-dev']
		memcached_deps.each{|dep|
			expect(chef_run).to install_package dep
		}
	end
end


describe "Installs postgres" do

  it "Updates the system" do
    expect(chef_run).to execute_command("sudo apt-get update")
  end

  it "Installs postgresql and restart" do
    expect(chef_run).to install_package("postgresql")
  end

  it "loads the postgres ph_hba conf file" do
    expect(chef_run).to create_file '/etc/postgresql/9.1/main/pg_hba.conf'
    file = chef_run.template('/etc/postgresql/9.1/main/pg_hba.conf')
    expect(file).to be_owned_by('postgres')
  end

  it "loads the postgres conf file" do
    expect(chef_run).to create_file '/etc/postgresql/9.1/main/postgresql.conf'
    file = chef_run.template('/etc/postgresql/9.1/main/postgresql.conf')
    expect(file).to be_owned_by('postgres')
  end

  it "restarts the postgres service" do
    expect(chef_run).to restart_service "postgresql"
  end

  it "creates root user " do
      expect(chef_run).to execute_command("createuser -U postgres -h localhost -s root")
  end
  it "creates-mics-user" do
    expect(chef_run).to execute_command("createuser -U postgres -h localhost -sw mics")
  end

  it "creates mics_db" do
    expect(chef_run).to execute_command("createdb -U mics -h localhost -O mics -E utf8 -T template0 mics")
  end
end

describe 'Install and restart nginx ' do

  it 'installs nginx' do
    expect(chef_run).to install_package("nginx")
  end

  it 'loads nginx configuration' do
    expect(chef_run).to create_file '/etc/nginx/nginx.conf'
    expect(chef_run).to create_file '/etc/nginx/conf.d/nginx.conf'
  end

  it 'restarts the nginx service' do
    expect(chef_run).to restart_service "nginx"
  end
end

describe 'install uwsgi' do
	
	it 'install uwsgi package' do
		expect(chef_run).to install_package 'uwsgi'
	end

	it 'installs uwsgi-plugin-python' do
		expect(chef_run).to install_package 'uwsgi-plugin-python'
	end
	
	it 'creates uwsgi mics.ini' do
		expect(chef_run).to create_file '/etc/uwsgi/apps-enabled/mics.ini'
		expect(chef_run).to create_file '/etc/uwsgi/apps-available/mics.ini'
	end
	
	it 'deletes /var/www/sockets/' do
			expect(chef_run).to execute_command('rm -rf /var/www/sockets')
	end
 
	it 're-creates /var/www/sockets/' do
		expect(chef_run).to execute_command('mkdir -p /var/www/ && mkdir -p /var/www/sockets')
	end	

	it 'starts uwsgi' do
		expect(chef_run).to start_service 'uwsgi'
	end
end
end
