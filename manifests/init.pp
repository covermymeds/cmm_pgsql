# == Class: cmm_pgsql
#
# This is a wrapper around the puppetlabs/postgresql module.
#
# Facts determine replication status.
#  pg_ismaster:
#   - if we are a master do everything normally
#   - if we are a slave, don't setup dbs, users, grants
#  pg_failover:
#   - if we are in failover DO NOTHING
#   - failover is a special mode where we don't want
#   puppet to enforce any configuration management
#
# To control the configuration of the server, use a Hiera hash:
#
#   cmm_pgsql::config:
#     'ssl':
#       value: on
#     'listen_addresses':
#       value: *
#
# This class *requires* our ssl class, so that we can use the SSL certificate
#
# cmm_pgsql::keysource should be overridden with a path to secure keys. This
# module used to contain sample keys for easy implementation and those have
# been removed to prevent people from using a key that is publicly accessible
#
class cmm_pgsql (
  $cluster              = 'dev',
  $repl_user            = 'repl',
  $repl_pass            = 'repl',
  $admin_user           = 'admin',
  $admin_pass           = 'admin',
  $keysource            = 'puppet:///modules/cmm_pgsql',
  $include_commvault    = true,
  $keepalived_notifylog = '/tmp/keepalived_notify.out',
  $keepalived_checklog  = '/tmp/keepalived_check.out',
  $pgbouncer_enabled    = false,
  $pg_ident             = {},
  $pg_hba_rule          = {},
) {

  # Do nothing while in failover
  unless str2bool($::pg_failover) {
    
    # include pgbouncer if enabled
    if $pgbouncer_enabled {
      include ::pgbouncer
    }

    include ::cmm_pgsql::setup

    # Is the server is in replication mode or not?
    # if it is, no writes should occur
    if str2bool($::pg_ismaster) {
    
      include ::cmm_pgsql::master

    } # End if $::is_pgmaster operations
  } # End unless $::pg_failover

}
