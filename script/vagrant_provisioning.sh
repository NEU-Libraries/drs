#!/usr/bin/env bash

/bin/bash --login

sudo yum -y install https://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo sed -i -e 's/^enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-Vault.repo

sudo sed -i -e 's,^ACTIVE_CONSOLES=.*$,ACTIVE_CONSOLES=/dev/tty1,' /etc/sysconfig/init

echo "Installing package dependencies"
sudo yum install ghostscript-8.70-19.el6.x86_64 --assumeyes
sudo yum install ImageMagick-devel-6.5.4.7-7.el6_5.x86_64 --assumeyes
sudo yum install java-1.6.0-openjdk java-1.6.0-openjdk-devel --assumeyes
sudo yum install file-devel --assumeyes
sudo yum install file-libs --assumeyes
sudo yum install sqlite-devel --assumeyes
sudo yum install redis --assumeyes
sudo yum install libreoffice-headless --assumeyes
sudo yum install unzip --assumeyes
sudo yum install zsh --assumeyes
sudo yum install mysql-devel --assumeyes
sudo yum install nodejs --assumeyes
sudo yum install htop --assumeyes
sudo yum install gcc gettext-devel expat-devel curl-devel zlib-devel openssl-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker --assumeyes
sudo yum install wget --assumeyes

echo "Making redis auto-start"
sudo chkconfig redis on
sudo service redis start

echo "Setting timezone for vm so embargo doesn't get confused"
echo 'export TZ=America/New_York' >> /home/vagrant/.zshrc
echo 'export TZ=America/New_York' >> /home/vagrant/.bashrc

echo "Installing Git"
wget https://www.kernel.org/pub/software/scm/git/git-1.8.2.3.tar.gz
tar xzvf git-1.8.2.3.tar.gz
cd /home/vagrant/git-1.8.2.3
make prefix=/usr/local all
sudo make prefix=/usr/local install
cd /home/vagrant
rm git-1.8.2.3.tar.gz
rm -rf /home/vagrant/git-1.8.2.3

echo "Installing FITS"
cd /home/vagrant
curl -O https://fits.googlecode.com/files/fits-0.6.2.zip
unzip fits-0.6.2.zip
chmod +x /home/vagrant/fits-0.6.2/fits.sh
sudo mv /home/vagrant/fits-0.6.2 /opt/fits-0.6.2
echo 'PATH=$PATH:/opt/fits-0.6.2' >> /home/vagrant/.bashrc
echo 'export PATH'  >> /home/vagrant/.bashrc
source /home/vagrant/.bashrc

echo "Installing RVM"
cd /home/vagrant
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable
source /home/vagrant/.profile
rvm pkg install libyaml
rvm install ruby-2.0.0-p598
rvm use ruby-2.0.0-p598
source /home/vagrant/.rvm/scripts/rvm

echo "Setting up Cerberus"
cd /home/vagrant/cerberus
gem install bundler
bundle install --retry 5
rake db:migrate
rails g hydra:jetty
rake jetty:config
rake db:test:prepare
rm -f /home/vagrant/cerberus/.git/hooks/pre-push
touch /home/vagrant/cerberus/.git/hooks/pre-push
echo '#!/bin/sh' >> /home/vagrant/cerberus/.git/hooks/pre-push
echo 'rake smoke_test' >> /home/vagrant/cerberus/.git/hooks/pre-push
chmod +x /home/vagrant/cerberus/.git/hooks/pre-push

echo "Installing Oh-My-Zsh"
cd /home/vagrant
\curl -Lk http://install.ohmyz.sh | sh
sudo chsh -s /bin/zsh vagrant
