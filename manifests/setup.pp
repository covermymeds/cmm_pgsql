class cmm_pgsql::setup (
  $pg_archive_dir = '/var/lib/pgsql/archive',
){

    $config = hiera_hash('cmm_pgsql::config', {})
    unless empty($config) {

      validate_hash($config)

      # Set a sane default for created resources
      $defaults = {
        ensure => 'present',
      }

      create_resources(::postgresql::server::config_entry, $config, $defaults)
    }

    #setup log management
    include ::cmm_pgsql::logrotate

    #include some helpful scripts
    include ::cmm_pgsql::scripts

    #include commvault backups
    if $::cmm_pgsql::include_commvault == true {
      include ::cmm_pgsql::commvault_backup
    }

    #setup pg_ident if values exist
    $_pg_ident = $::cmm_pgsql::pg_ident 
    unless empty($_pg_ident) {
      create_resources(postgresql::server::pg_ident_rule, $_pg_ident)
    }

    #setup pg_hba_rule if values exist
    $_pg_hba_rule = $::cmm_pgsql::pg_hba_rule
    unless empty($_pg_hba_rule) {
      create_resources(postgresql::server::pg_hba_rule, $_pg_hba_rule)
    }


    #setup postgres ssh keys
    unless empty($::cmm_pgsql::keysource) {
      file { "/var/lib/pgsql/.ssh":
        ensure => "directory",
        owner  => "${::postgresql::server::user}",
        group  => "${::postgresql::server::group}",
        mode   => 700,
        require=> Class['::postgresql::server::initdb'],
      } ->
      file { "/var/lib/pgsql/.ssh/id_rsa":
        mode => "0600",
        owner => "${::postgresql::server::user}",
        group => "${::postgresql::server::group}",
        source => "${::cmm_pgsql::keysource}/id_rsa",
      } ->
      file { "/var/lib/pgsql/.ssh/id_rsa.pub":
        mode => "0600",
        owner => "${::postgresql::server::user}",
        group => "${::postgresql::server::group}",
        source => "${::cmm_pgsql::keysource}/id_rsa.pub",
      } ->
      file { "/var/lib/pgsql/.ssh/authorized_keys":
        mode => "0600",
        owner => "${::postgresql::server::user}",
        group => "${::postgresql::server::group}",
        source => "${::cmm_pgsql::keysource}/authorized_keys",
      }

    } # End unless ::cmm_pgsql::keysource

    # Setup SSL certs and keys for pgclient communication
    file { "${::postgresql::params::datadir}/server.crt":
      owner   => $::postgresql::server::user,
      group   => $::postgresql::server::group,
      source  => "file://${::ssl::cert}",
      mode    => '0400',
      require => Class['::postgresql::server::initdb'],
    }

    file { "${::postgresql::server::datadir}/server.key":
      owner   => $::postgresql::server::user,
      group   => $::postgresql::server::group,
      source  => "file://${::ssl::key}",
      mode    => '0400',
      require => Class['::postgresql::server::initdb'],
    }

    $_packages = [
      "pg_repack${::postgresql::server::package_version}",
      "pg_top${::postgresql::server::package_version}",
      "postgresql${::postgresql::server::package_version}-contrib",
      "slony1-${::postgresql::server::package_version}",
    ]

    package { $_packages:
      ensure  => installed,
      require => Class['postgresql::repo::yum_postgresql_org'],
    }

    # Pull in monitor data from hiera and create the checks
    $_monitors = hiera_hash('cmm_pgsql::monitoring', {})

    #create monitors from generic data or with what is defined for host in hiera
    unless empty($_monitors) {
      create_resources(::cmm_pgsql::monitoring_wrapper, $_monitors)
    }


}
