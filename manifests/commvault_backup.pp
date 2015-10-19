class cmm_pgsql::commvault_backup (
  $pg_archive_dir = $::cmm_pgsql::setup::pg_archive_dir,
)
{
  file { $pg_archive_dir:
    ensure  => 'directory',
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0750',
    require => Class['::postgresql::server::initdb'],
  }

  package { 'cmm-cv_iDA-pgsql':
    ensure => installed,
  }
}
