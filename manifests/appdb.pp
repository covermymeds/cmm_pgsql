# Define type for creating an application specific database.
#
# This is a custom implementation of ::postgresql::server::db
# since we don't want the default behavior of that upstream defined
# type.
#
# Requirements here that are custom:
#  - Don't create a single owner for the database
#  - The 'postgres' role owns all databases
#  - Don't GRANT ALL to a single owner
#  - We have multiple app users per database
#  - Don't implement tablespaces (yet)
define cmm_pgsql::appdb (
  $apps,
  $dbname     = $title,
  $encoding   = $postgresql::server::encoding,
  $locale     = $postgresql::server::locale,
  $tablespace = undef,
  $template   = 'template1',
  $istemplate = false,
  $owner      = undef
) {
  # Ensure the $apps parameter is an array
  validate_array($apps)

  # Create our application database
  if ! defined(Postgresql::Server::Database[$dbname]) {
    postgresql::server::database { $dbname:
      encoding   => $encoding,
      tablespace => $tablespace,
      template   => $template,
      locale     => $locale,
      istemplate => $istemplate,
      owner      => $owner,
    }
  }

  # Add a separator using ':' to uniquely declare db handles
  # Then in the cmm_pgsql::dbhandle the ':' will be used to 
  # deconstruct the title into app and database names
  $unique_apps = prefix($apps, "${dbname}:")
  cmm_pgsql::dbhandle { $unique_apps:
    require  => Postgresql::Server::Database[$dbname],
  }

}
