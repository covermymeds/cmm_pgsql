class cmm_pgsql::central_logging {

  # Ship logs via beaver
  if $::app_env != 'development' {
    ensure_resource('Beaver::Stanza', "${::postgresql::server::datadir}/pg_log/*.log", {
      type    => 'pgsql',
      tags    => ['pgsql'],
      require => Class['::central_logging::beaver'],
    })
  }
}
