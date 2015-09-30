define cmm_pgsql::dbhandle {
  # Decompose the $title into 'database:appname'
  $_handle = split($title, ':')

  unless ( count($_handle) == 2 ) {
    fail('The $title should be in the form of "database:appname"')
  }

  $_database = $_handle[0]
  $_appname = $_handle[1]

  # There will be several application users for each
  # database. Each app user will represent a handle

  # Lookup the application to dbhandle mapping
  $_hiera_lookup = "app::dbconfig::${_appname}"
  $_appconfig = hiera_hash($_hiera_lookup, {})

  if empty($_appconfig) {
    fail("Missing hiera config for '${_hiera_lookup}'")
  }

  if has_key($_appconfig, $_database) {
    $_dbconfig = $_appconfig[$_database]
    $unique_dbconfig = prefix_keys($_dbconfig, "${_database}_${_appname}_")
  } else {
    fail("Database ${_database} not found in ${_appname} config")
  }

  create_resources(::cmm_pgsql::appuser, $unique_dbconfig)

}
