class cmm_pgsql::scripts{

  $_datadir              = $::postgresql::server::datadir
  $_bindir               = $::postgresql::server::bindir
  $_pgversion            = $::postgresql::globals::version
  $_archive              = $::cmm_pgsql::setup::pg_archive_dir
  $_repl_user            = $::cmm_pgsql::repl_user
  $_repl_pass            = $::cmm_pgsql::repl_pass
  $_keepalived_notifylog = $::cmm_pgsql::keepalived_notifylog

  # copy cmm management files into place for postgres
  file { '/usr/local/src/make_pg_slave.sh':
    mode    => '0500',
    owner   => 'root',
    group   => 'root',
    content => template('cmm_pgsql/scripts/make_pg_slave.sh.erb'),
  }
  file { '/usr/local/src/failover_postgres_from_slave.sh':
    mode    => '0500',
    owner   => 'root',
    group   => 'root',
    content => template('cmm_pgsql/scripts/failover_postgres_from_slave.sh.erb'),
  }
  file { '/usr/local/src/failover_postgres_from_master.sh':
    mode    => '0500',
    owner   => 'root',
    group   => 'root',
    content => template('cmm_pgsql/scripts/failover_postgres_from_master.sh.erb'),
  }
  file { '/usr/local/src/clean_archive.sh':
    mode    => '0500',
    owner   => 'root',
    group   => 'root',
    content => template('cmm_pgsql/scripts/clean_archive.sh.erb'),
  }
  file { '/usr/local/src/keepalived_notify.sh':
    mode    => '0500',
    owner   => 'root',
    group   => 'root',
    content => template('cmm_pgsql/scripts/keepalived_notify.sh.erb'),
  }

}
