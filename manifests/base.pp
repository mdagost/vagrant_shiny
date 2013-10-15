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
  package { "emacs":
    ensure => present,
    require => Class['update_package_list'], 
  }
}

class psql {
  package { ["postgresql-client-common", "postgresql-client-9.1"]:
    ensure => present,
    require => Class['update_package_list'], 
  }
}

class wget {
  package { "wget":
    ensure => present,
    require => Class['update_package_list'], 
  }
}

class add_repos {
  file_line { '/etc/apt/sources.list':
    path => '/etc/apt/sources.list',
    line => 'deb http://cran.rstudio.com/bin/linux/ubuntu precise/',
  }

  exec { 'add-cran-key':
    command => '/usr/bin/apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 51716619E084DAB9'
  } 	    

  exec { 'add-apt-repository ppa:chris-lea/node.js':
    command => '/usr/bin/add-apt-repository ppa:chris-lea/node.js'
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
    ensure => "3.0.0-2precise",
    require => Class['add_repos', 'update_package_list'], 
  }
}

class nodejs {
  $node_packages = ["python-software-properties", "python", "g++", "make", "nodejs"]
  package { $node_packages:
    ensure => present,
    require => Class['add_repos', 'update_package_list'], 
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

class shiny_upstart {
  exec { 'wget':
    command => "/usr/bin/wget http://raw.github.com/rstudio/shiny-server/master/config/upstart/shiny-server.conf -O /etc/init/shiny-server.conf",
    creates  =>  "/etc/init/shiny-server.conf",
    require => Class["shiny", "wget"],
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
    provider => "upstart",
    require => Class["shiny", "shiny_upstart"],
  }
}

include apache
include emacs
include wget
include psql
include add_repos
include update_package_list
include r-base
include stdlib
include nodejs
include shiny
include shiny_upstart
include copy_shiny_examples
include start_shiny
