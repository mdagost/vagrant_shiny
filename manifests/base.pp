# Basic Puppet Apache manifest

class apache {
  package { "apache2":
    ensure => present,
    require => Class['update_package_list'], 
  }

  service { "apache2":
    ensure => running,
    require => Package["apache2"],
  }

  file { '/var/www':
    ensure => link,
    target => "/vagrant",
    notify => Service['apache2'],
    force  => true
  }
}

class emacs {
  package { ["emacs", "ess"]:
    ensure => present,
    require => Class['update_package_list'], 
  }
}

class psql {

  package { "libpq5":
    ensure => "9.1.9-1~bpo60+1",
    require => Class['update_package_list'],
  }

  package { "libpq-dev":
    ensure => "9.1.9-1~bpo60+1",
    require => [Class['update_package_list'], Package['libpq5']], 
  }

  package { "postgresql-client-common":
    ensure => "134wheezy3~bpo60+1",	
    require => Class['update_package_list'],
  }

  package { "postgresql-client-9.1":
    ensure => "9.1.9-1~bpo60+1",	
    require => [ Class['update_package_list'], Package['postgresql-client-common'] ],
  }

  package { "postgresql-common":
    ensure => "134wheezy3~bpo60+1",	
    require => Class['update_package_list'],
  }

  package { "postgresql-9.1":
    ensure => "9.1.9-1~bpo60+1",	
    require => [ Class['update_package_list'], Package['postgresql-common'] ],
  }

}

class wget {
  package { "wget":
    ensure => present,
    require => Class['update_package_list'], 
  }
}

class add_repos {
  file_line { '/etc/apt/sources.list backports':
    path => '/etc/apt/sources.list',
    line => 'deb http://debian.cs.binghamton.edu/debian-backports squeeze-backports main',
  }

  file_line { '/etc/apt/sources.list cran':
    path => '/etc/apt/sources.list',
    line => 'deb http://cran.rstudio.com/bin/linux/debian squeeze-cran3/',
  }

  exec { 'add-cran-key':
    command => '/usr/bin/apt-key adv --keyserver subkeys.pgp.net --recv-key 381BA480'
  }  
}

class update_package_list {
  exec { 'apt-get update':
    command => '/usr/bin/apt-get update',
    require => Class['add_repos'],
  }
}

class r-base {
  package { "r-base-core":
    ensure => "3.0.2-1~squeezecran3.0",
    require => Class['add_repos', 'update_package_list'], 
  }
}

class r-packages {
  $R_packages = ["ggplot2", "lubridate", "RPostgreSQL"]	

  define r_package {
    exec { "Installing R package $title":
    command => "/usr/bin/R -e \"install.packages('${title}', repos='http://cran.rstudio.com/')\"",
    require => Class['r-base'],		
    }
  }

  r_package { $R_packages: }
}

class nodejs {
  $node_packages = ["python", "g++", "curl", "libssl-dev", "make"]
  package { $node_packages:
    ensure => present,
    require => Class['add_repos', 'update_package_list', 'wget'], 
  }

  file { "/tmp/nodejs/":
    mode => 777,
    ensure => "directory",
  }
  
  exec { "Download node":
    command => "/usr/bin/wget http://nodejs.org/dist/node-latest.tar.gz",
    cwd     => "/tmp/",
    creates => "/tmp/node-latest.tar.gz",
    require => File['/tmp/nodejs/'],
  }

  exec { "Prepare node":
    command => "/bin/tar xzf /tmp/node-latest.tar.gz --directory=nodejs --strip-components=1",
    cwd     => "/tmp/",
    creates => "/tmp/nodejs/configure",
    require => Exec["Download node"],
  }

  exec { "Configure node":
    command => "/tmp/nodejs/configure --prefix=/usr/",
    cwd     => "/tmp/nodejs/",
    require => Exec["Prepare node"],
  }

  exec { "Build node":
    command => "/usr/bin/make -C /tmp/nodejs",
    cwd     => "/tmp/nodejs",
    creates => "/tmp/nodejs/out/Release/node",
    require => [ Exec["Configure node"], Package[$node_packages] ],
  }

  exec { "Install node":
    command => "/usr/bin/make -C /tmp/nodejs install",
    cwd     => "/tmp/",
    creates => "/usr/local/bin/node",
    require => Exec["Build node"],
  }
}

class shiny {
  exec { 'shiny package':
    command => "/usr/bin/R -e \"install.packages('shiny', repos='http://cran.rstudio.com/')\"",
    require => Class['r-base'], 
    timeout => 600,
  }
  exec { 'shiny server':
    command => "/usr/bin/npm install -g shiny-server",
    environment => [ "HOME=/home/vagrant/" ],
    require => Class['nodejs'],
  }
  $dirs = ["/var/shiny-server", "/var/shiny-server/www", "/var/shiny-server/log"]
  file { $dirs:
    ensure => "directory",
  }
  user { "shiny":
    ensure => present,
  }
}

class shiny_initd {
  exec { 'wget':
    command => "/usr/bin/wget https://gist.github.com/mdagost/7155924/raw/d152e653f0e8be357394dfa6aeb67efeeac427bc/shiny-server -O /etc/init.d/shiny-server",
    creates  =>  "/etc/init.d/shiny-server",
    require => Class["shiny", "wget"],
  }      

  file { '/etc/init.d/shiny-server':
    ensure => present,
     mode => 777,  
  }
}

class copy_shiny_examples {
  exec { "copy shiny examples":
  command => "/bin/cp -R /usr/local/lib/R/site-library/shiny/examples /var/shiny-server/www/",
  require => Class["shiny"],
  }
}

class start_shiny {
  service { "shiny-server":
    ensure => running,
    require => Class["shiny", "shiny_initd"],
  }
}

include apache
include emacs
include wget
include psql
include add_repos
include update_package_list
include r-base
include r-packages
include stdlib
include nodejs
include shiny
include shiny_initd
include copy_shiny_examples
include start_shiny
