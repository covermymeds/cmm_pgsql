class cmm_pgsql::create_objects {
  # Look up hieradata for our list of databases
  $_dblist = hiera("cmm_pgsql::dblist::${::cmm_pgsql::cluster}", {})

  # iterate over all the DBs defined in our dblist
  $_dblist.each |$db, $db_values| {
    # set some defaults for database resources
    $db_defaults = {
      template   => 'template1',
      encoding   => $postgresql::server::encoding,
      locale     => $postgresql::server::locale,
      tablespace => undef,
      istemplate => false,
      owner      => undef
    }

    # Create our application database
    if ! defined(Postgresql::Server::Database[$db]) {
      postgresql::server::database { $db:
        * => $db_defaults,
      }
    }

    # Ensure the apps key is an array
    validate_array($db_values['apps'])

    # iterate over our the apps in the dblist database
    $db_values['apps'].each |$app| {

      # Lookup the application to dbhandle mapping
      $_appconfig = hiera_hash("app::dbconfig::${app}", {}) #STREAMLINE? this is likely calling duplicate dbconfigs, see etl

      if empty($_appconfig) {
        fail("Missing hiera config for 'app::dbconfig::${app}'")
      }

      # iterate over the databases in the dbconfig
      $_appconfig[$db].each |$appuser, $dbinfo| {

        # Don't setup non-postgresql
        # Don't create duplicate users
        if $adapter == 'postgresql' {
          # these are optional, so set defaults
          $default_handle = pick($dbinfo['default_handle'], false)
          $schema         = pick($dbinfo['schema'], 'public')

          $appdb    = $dbinfo['database']
          $host     = $dbinfo['host']
          $password = $dbinfo['password']
          $role     = $dbinfo['role']
          $username = $dbinfo['username']

          # create application user
          unless defined(Postgresql::Server::Role[$username]) {
            postgresql::server::role { $username:
              password_hash => postgresql_password($username, $password),
              login         => true,
            }
          }

          if $::cmm_pgsql::pgbouncer_enabled {
            unless defined(Pgbouncer::Userlist["cmm_pgsql_module_${username}"]) {

              # create pgbouncer auth_list config
              pgbouncer::userlist{ "cmm_pgsql_module_${username}":
                auth_list => [ { user => $username, password => $password }, ],
              }
            }

            unless defined(Pgbouncer::Databases["cmm_pgsql_module_${appdb}_${username}"]) {

              # create database config section of pgbouncer.ini
              pgbouncer::databases {"cmm_pgsql_module_${appdb}_${username}":
                databases => [ { source_db => $appdb, host => $host, dest_db => $appdb, auth_user => $username }, ],
              }
            }
          }

          # give permission for user to connect to the database
          $connect_grant = "connect: ${username}@${appdb}"
          unless defined(Postgresql::Server::Database_grant[$connect_grant]) {
            postgresql::server::database_grant{ $connect_grant:
              privilege => 'CONNECT',
              db        => $appdb,
              role      => $username,
              require   => Postgresql::Server::Role[$username],
            }
          }

          # give permissions to the user on the schema
          $schema_create = "${appdb}: CREATE SCHEMA \"${schema}\""
          unless defined(Postgresql::Server::Schema[$schema_create]) {
            postgresql::server::schema{ $schema_create:
              db     => $appdb,
              owner  => $::postgresql::server::user,
              schema => $schema,
            }
          }

          $role_grants = "role:${role} ${schema} ${username}@${appdb}"
          unless defined(Postgresql_psql[$role_grants]) {
            postgresql_psql { $role_grants:
              command    => template("cmm_pgsql/grants/${role}.sql.erb"),
              db         => $appdb,
              psql_user  => $::postgresql::server::user,
              psql_group => $::postgresql::server::group,
              psql_path  => $::postgresql::server::psql_path,
              unless     => "SELECT nspname, defaclobjtype, defaclacl
                           FROM pg_default_acl a
                           JOIN pg_namespace b ON a.defaclnamespace=b.oid
                           WHERE defaclobjtype = 'r'
                           AND nspname = '${schema}'
                           AND aclcontains(defaclacl, '\"${username}\"=r/postgres')",
              require    => [ Postgresql::Server::Role[$username], Postgresql::Server::Schema[$schema_create] ],
            }
          }
        }
      }
    }
  }
}
