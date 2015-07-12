# How to install

The full Orfeo system has three primary parts:

 * The import workflow, which is mainly a Ruby script.
 * The metadata search / sample page interface.
 * ANNIS, which consists of a web interface (servlet) and a service (in Java) and uses a PostgreSQL database.

In fuller detail, the complete system consists of various separate processes and services:

 * The importer script (run when converting and importing data)
 * The search portal, running under Apache (or nginx) using the Passenger module (or on a WEBrick server for development only)
 * An Apache Solr instance running in a servlet container (e.g. Jetty)
 * A web server where the sample pages can be accessed
 * A servlet container (e.g. Tomcat) where the ANNIS GUI is
 * `annis-service`, which listens to requests from the ANNIS GUI
 * PostgreSQL (used by ANNIS)

In principle these 7 services could run on 7 different servers. These instructions suggest installing all of them on one server, but that is for simplicity only, not an actual implementation constraint.


## Installation script

The installation script [install-or-update.rb](install-or-update.rb) automates most of the installation process. It is particularly recommended because it helps to set up parameters that are required by the distinct parts of the app to correctly link to each other.

The script should be run as a normal user, never with root privileges. The script can be re-run at any time, in which case it will update the existing installation if updates are available. Note that the installation script will not update itself.

In principle, you only need to have Ruby to run the installation script. See below for the suggested Ruby setup. The rest of this document describes steps that may or may not need to be taken, depending on how many of the steps of the installation script succeed without user intervention.

The installer is relatively safe in the sense that it will only modify
files under the directory it is executed in. (It may also install Ruby
gems.)


## Ruby

The importer and text search are implemented in Ruby. Thus, the first step is to ensure Ruby is installed. At least version 1.9.3 of the Ruby interpreter is required and a much newer version (2.2.0 is current at the time of writing this) is recommended.

It is possible to install Ruby and other packages in the Ruby ecosystem using the standard package management tools (e.g. `apt-get`). However, often the packages in official repositories are relatively old, which may cause problems. The recommended setup is to use `rbenv` (a helper app that allows several versions of Ruby to be installed and switched, without causing a dependency hell between different library versions) to install Ruby and all Ruby-based packages in the home directory of the user that will own the Orfeo tool installation directory.

The universal method is install `git` and follow the instructions at [rbenv's GitHub page](https://github.com/sstephenson/rbenv#basic-github-checkout) to install rbenv and ruby-build as a plugin:

```
sudo apt-get install git
git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
```

Check for available versions:

```
rbenv install -l
```

Choose an appropriate version and give these commands, changing the version number as appropriate:

```
rbenv install 2.0.0-p643
rbenv global 2.0.0-p643
```

Note that when the installation script is run, it will attempt to install any missing dependencies, but only with user privileges. Therefore, if Ruby and `gem` are installed in a location not writable by the user (either via `apt-get` or using `rbenv` with a non-default location), all package install attempts by the script will fail and have to be run manually.


## Passenger

The above is already enough to run the search site in development mode using WEBrick. For production, the next step is to integrate it with a web server, which we'll assume is Apache. (The web server should be installed and set up before you proceed from this point. Other servers like nginx are also supported but no instructions for those are included here.) So install the Phusion Passenger module:

```
gem install passenger
rbenv rehash
sudo passenger-install-apache2-module
```

Next, edit the Apache configuration file. The simplest way is to copy and paste the five lines the above command prints out and tells you to use. It looks like this (except that `xyz` is an actual path):

```
LoadModule passenger_module /xyz/mod_passenger.so
<IfModule mod_passenger.c>
  PassengerRoot /xyz/gems/passenger-5.0.6
  PassengerDefaultRuby /xyz/bin/ruby
</IfModule>
```

Finally, add the following to your Apache configuration (`/etc/apache2/default-server.conf` or a separate virtual host if applicable):

```
<Directory /xyz/public>
  # This relaxes Apache security settings.
  AllowOverride all
  # MultiViews must be turned off.
  Options -MultiViews
  # Uncomment this if you're on Apache >= 2.4:
  Require all granted
</Directory>
```

where `/xyz/public` is the directory where the search application is located.


## Installing ANNIS

ANNIS is completely dependent on its database and is also specific to its version. Other than that, it is a listener service (daemon) coupled with a Java servlet GUI.

### Installing and setting up PostgreSQL

At least version 9.3 is ''required'' (later versions, at least 9.4, work fine). It is pretty much impossible to "tweak" 9.2 to work so don't bother to try.

Here's a summary of the steps on an Ubuntu server (change passwords as you see fit, but make sure the passwords given to psql and annis-admin match):

```
sudo apt-get install postgresql-9.3 postgresql-client-9.3 postgresql-common postgresql-client-common postgresql-contrib-9.3
sudo su - postgres
createuser -DRS orfeodb
psql
  alter user postgres with password 'cmp6qzyzwfve';
  alter user orfeodb with password 'eazw68bbx4n2';
exit
source settings.sh
annis-admin.sh init -u orfeodb -d orfeo -p eazw68bbx4n2 -P cmp6qzyzwfve
annis-service-no-security.sh restart
```
