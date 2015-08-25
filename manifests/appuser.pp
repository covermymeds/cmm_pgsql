define cmm_pgsql::appuser (
  $default_handle = false,
  $pgbouncer_on   = false,
  $role,
  $database,
  $adapter,
  $host,
  $username,
  $password,
) {

  # Don't setup non-postgresql
  # Don't create duplicate users
  if $adapter == 'postgresql' {

    # create application user
    unless defined(Postgresql::Server::Role[$username]) {
      postgresql::server::role { $username:
        password_hash => postgresql_password($username, $password),
        login         => true,
      }
    }

    if $pgbouncer_on {
      unless defined(Pgbouncer::Userlist["cmm_pgsql_module_${username}"]) {

        # create pgbouncer auth_list config
        pgbouncer::userlist{ "cmm_pgsql_module_${username}":
          auth_list => [ { user => $username, password => $password }, ],
        } 
      }

      unless defined(Pgbouncer::Database["cmm_pgsql_module_${database}_${username}"]) {

        # create database config section of pgbouncer.ini
        pgbouncer::databases {"cmm_pgsql_module_${database}_{username}":
          databases => [ { source_db => $database, host => $host, dest_db => $database, auth_user => $username }, ],
        }
      }
    }

    # give permission for user to connect to the database
    $connect_grant = "connect: ${username}@${database}"
    unless defined(Postgresql::Server::Database_grant[$connect_grant]) {
      postgresql::server::database_grant{ $connect_grant:
        privilege => 'CONNECT',
        db        => $database,
        role      => $username,
        require   => Postgresql::Server::Role[$username],
      }
    }

    $role_grants = "role:${role} ${username}@${database}"
    unless defined(Postgresql_psql[$role_grants]) {
      postgresql_psql { $role_grants:
        command    => template("cmm_pgsql/grants/${role}.sql.erb"),
        db         => $database,
        psql_user  => $::postgresql::server::user,
        psql_group => $::postgresql::server::group,
        psql_path  => $::postgresql::server::psql_path,
        unless     => "SELECT nspname, defaclobjtype, defaclacl
                     FROM pg_default_acl a
                     JOIN pg_namespace b ON a.defaclnamespace=b.oid
                     WHERE defaclobjtype = 'r'
                     AND aclcontains(defaclacl, '\"${username}\"=r/postgres')",
        require    => Postgresql::Server::Role[$username],
      }
    }
  }

}
