class cmm_pgsql::master {

  # Admin user that can administer via TCP and has global permissions
  postgresql::server::role { $::cmm_pgsql::admin_user:
    password_hash => postgresql_password($::cmm_pgsql::admin_user, $::cmm_pgsql::admin_pass),
    superuser     => true,
    createrole    => true,
    createdb      => true,
    replication   => true,
  }

  # Create maintenance database for admin user
  # This needs to run after creation of admin role
  postgresql::server::database { $::cmm_pgsql::admin_user:
    owner   => $::cmm_pgsql::admin_user,
    require => Postgresql::Server::Role[$::cmm_pgsql::admin_user],
  }

  # Create the deployment database
  # Default owner is 'postgres' user
  postgresql::server::database { 'deployments': }

  # create a user for root that doesn't have a password (used for backups)
  # the root role purposely doesn't get a database.
  postgresql::server::role { 'root':
    password_hash => postgresql_password('root', ''),
    superuser     => true,
  }

  # create the replication user and assign the appropriate permissions
  postgresql::server::role { $::cmm_pgsql::repl_user:
    password_hash => postgresql_password($::cmm_pgsql::repl_user, $::cmm_pgsql::repl_pass),
    replication   => true,
  }

  # change template1 permissions to not allow create
  $revoke_create = 'revoke create on schema public from public'
  postgresql_psql { $revoke_create:
    db         => 'template1',
    psql_user  => $::postgresql::server::user,
    psql_group => $::postgresql::server::group,
    psql_path  => $::postgresql::server::psql_path,
    unless     => "select 1 where (select has_schema_privilege('${::cmm_pgsql::repl_user}','public','CREATE')) = 'f'",
    require    => [ Class['Postgresql::Server'], Postgresql::Server::Role[$::cmm_pgsql::repl_user] ],
  }


  # Look up hieradata for our list of databases
  $_dblist = hiera("cmm_pgsql::dblist::${::cmm_pgsql::cluster}", {})
  
  unless empty($_dblist) {

    # Create our database(s)
    create_resources(::cmm_pgsql::appdb, $_dblist)

  }

  # install admin pack (prevents pgAdminIII from griping about features)
  postgresql_psql{'verify_adminpack_installed':
    command => 'CREATE EXTENSION adminpack;',
    unless  => "SELECT extname from pg_extension WHERE extname = 'adminpack'",
  }

  $_config = $::cmm_pgsql::setup::config
  if (has_key($_config, 'shared_preload_libraries')) {
    $_sharedlib = $_config['shared_preload_libraries']
    unless empty($_sharedlib) {
      if 'pg_stat_statements' in $_sharedlib {
        postgresql_psql {'verify_pg_stat_statements_installed':
          command => 'CREATE EXTENSION pg_stat_statements;',
          unless  => "SELECT extname from pg_extension WHERE extname = 'pg_stat_statements'",
        }
      }
    }
  }

}
