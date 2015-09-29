class cmm_pgsql::logrotate (
  $daysuntildelete   = 30,
  $daysuntilcompress = 1,
)
{
  # The pgdata directory must exist
  require ::postgresql::server
  require ::logrotate

  $_pgdata = $::postgresql::server::datadir

  #requires empty file for rotation because logrotate doesn't handle another 
  #process (postgresql) handling the actual rotation and naming of log files
  #rotation is actually managing deletion and compression of logs using 
  #a post rotate process
  file { "${_pgdata}/pg_log/logrotate":
    ensure  => present,
    replace => 'no', # this is the important property
    content => '', #empty file
    mode    => '0444',
  }

  file { '/etc/logrotate.d/postgresql':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('cmm_pgsql/logrotate/postgresql.erb'),
    require => Class[::logrotate],
  }

}
