#cmm_pgsql

####Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Getting started with [cmm_pgsql]](#setup)
    * [What [cmm_pgsql] affects](#what-[cmm_pgsql]-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with [cmm_pgsql]](#beginning-with-[Modulename])
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
7. [Contributing](#contributing)
8. [Copyright](#copyright)

##Overview

This module is an intermediate tech module (read CMM specific) for applying a standard postgresql cluster build.

##Module Description

By default, this does setup of the following build standards:
  - Installs some base pg packages CMM depends on
  - Setup of 'admin' postgresql role
  - Setup of 'root' postgresql role for backups
  - Customization of the 'template1' database to use for new 'app' databases.
  - Creation of application databases, users and grants
  - Export of postgresql monitoring checks

##Setup

###What [cmm_pgsql] affects

* This will install postgresql server, keepalived and several pg specific packages
* This module is highly dependent on hieradata structures to build pg role and database configuration
* Hieradata structures are optional and should not be required
* If postgres server has a recovery.done file puppet assumes a failover state and exits without changing anything
* If a postgres server has a recovery.conf file it is assumed the server is a slave and puppet does not try to manage users or databases


###Setup Requirements **OPTIONAL**

This module uses the [puppetlabs/puppet-postgresql](https://forge.puppetlabs.com/puppetlabs/postgresql)  module to implement the build standard operations.
It also uses [arioch/keepalived](https://forge.puppetlabs.com/arioch/keepalived) for initial setup master/slave failover awareness.
It requires use of [puppet/ssl](https://git.innova-partners.com/puppet/ssl) and enforces ssl enabled database connections

	
###Beginning with [cmm_pgsql]	

* Vanilla database setup can be completed as follows:
```
  include ::ssl
  include ::postgresql::globals
  include ::postgresql::server
  include ::cmm_pgsql

  # ::postgresql::globals must set its config
  # entries before ::postgresql::server can be setup
  Class['::postgresql::globals']
  -> Class['::postgresql::server']

  # ::ssl certs must be defined before ::cmm_pgsql
  # can utilize them in its setup
  Class ['::ssl']
  -> Class['::cmm_pgsql']

```

##Usage

Example use of parameters and hieradata structures

Define the database host cluster membership

```
cmm_pgsql::cluster: 'pgc0'
```

Define the databases and applications that will utilize this cluster
  - use a 'common' area of hieradata for this definition
  - this data structure will be shared be multiple posgresql hosts

Format:
```
cmm_pgsql::dblist::<cluster>
  <database_name>:
    apps:
      - <app1>
      - <app2>
```

Example:
```
cmm_pgsql::dblist::pgc0:
  form_search:
    apps:
      - claims
      - forms-api
  reporting_api:
    apps:
      - reporting-api
  dw_reporting:
    apps:
      - reporting-api
  deploywizard:
     apps:
      - deploywizard
```

Define the application database configuration
  - This configuration is shared with applications
  - Hashes are application specific and use ```hiera()` priority lookup and not a merged lookup.
  - The [puppet/app](https://git.innova-partners.com/puppet/app) will use this same data structure to create python, php and ruby application credentials
  - The data structure is very long and very verbose
  - The complexity will support:
    - Multiple databases per application
    - Multiple db handles per application (write, immediate readonly, slave readonly)
    - Data sharing with other app modules.
    - One stop shop for credentials

Format:
```
app::dbconfig::<appname>:
  <database_name>:
    <handle_name>:
      default_handle: [true|false]
      host: <database vip hostname>
      role: <role_name>             # Must match a grants template in ```templates/grants/*.sql.erb```
      database: <database_name>     # Redundant, but explicit for both ```::cmm_pgsql``` and ```::app`` modules to function
      adapter: sqlserver|postgresql # Useful for the module to only determine credential setup
      username: <db_username>       # 'app_name' + 'role' + 'YYQ' ex: forms_api_wr_143
      password: <db_password>
```

Example(s):
```
# App name: deploywizard
app::dbconfig::deploywizard:
  deploywizard:
    primary_write:
      default_handle: true
      host: dc0p_vip_deploywizard_wr
      role: default_write
      database: deploywizard
      adapter: postgresql
      username: deploywizard_wr_143
      password: password

# App name: forms-api
app::dbconfig::forms-api:
  cmm2:
    primary_write:
      default_handle: true
      host: delhi.innova.local
      database: CMM2
      adapter: sqlserver
      username: autobahn_user
      password: ta3Rap@echeB
  form_search:
    primary_write:
      default_handle: true
      role: default_write
      host: dc0p_vip_forms_search_wr
      database: form_search
      adapter: postgresql
      username: forms_api_wr_143
      password: password
    immediate_read:
      default_handle: true
      role: default_readonly
      host: dc0p_vip_forms_search_wr
      database: form_search
      adapter: postgresql
      username: forms_api_ro_143
      password: password
    slave_read:
      default_handle: true
      role: default_readonly
      host: dc0p_vip_forms_search_ro
      database: form_search
      adapter: postgresql
      username: forms_api_ro_143
      password: password

# App name: reporting-api
app::dbconfig::reporting-api:
  reporting_api:
    primary_write:
      default_handle: true
      host: dc0p_vip_reporting_api_wr
      database: reporting_api
      adapter: postgresql
      username: reporting_api_wr
      password: password
  dw_reporting:
    read_only:
      default_handle: true
      host: dc0p_vip_dw_reporting_ro
      role: default_readonly
      database: dw_reporting
      adapter: postgresql
      username: dw_reporting_wr
      password: password
```

Finally, define host specific config for the postgresql instance
  - this uses ```hiera_hash`` to perform a deep merge of hiera data
  - it can be overridden or added to at the host or env level

```
cmm_pgsql::config:
  'hot_standby_feedback':
    value: 'on'
  'ssl':
    value: 'on'
  'ssl_renegotiation_limit':
    value: '0'
  'wal_level':
    value: 'hot_standby'
  'max_wal_senders':
    value: '5'
  'wal_keep_segments':
    value: '100'
  'wal_buffers':
    value: '8MB'
  'wal_sync_method':
    value: 'fdatasync'
  'hot_standby':
    value: 'on'
  'max_connections':
    value: '100'
  'shared_buffers':
    value: '1024MB'
```

Define shinken monitors with nagios plugins
  - Specify conservative values that can go in common.yaml.
  - It is better to have monitors on all new hosts with low thresholds than to expect data in the host specific file and forget monitors
  - Override defaults on an individual basis in the host file
  - Password for checks is based on ".pgpass" file in shinken users home directory.  Contents look like "*:5432:*:username:password"

Example:
```
cmm_pgsql::monitoring:
  'check_postgresql_backends':
    monitor_args: '--action backends-u admin -w 60 -c 80'
  'check_postgresql_txn_time':
    monitor_args: '--action txn_time -u admin -w 5 -c 10'
  'check_postgresql_wal_files':
    monitor_args: '--action wal_files -u admin -w 10 -c 15'
  'check_postgresql_hitratio':
    monitor_args: '--action hitratio -u admin --exclude=admin,postgres,template1'
```

##Summary

Go forth and build postgres clusters.


##Contributing

We are releasing this to share our ideas on implementing user management and control within postgres while sharing credentials with application code.  This module has information specific to our implementation currently and should not be considered as a drop in module.  That being said, if you would like to submit a pull request to have something changed or updated please feel free to do so.  If it doesn't affect the way we are using it there is a good chance it will get merged.

##Copyright

Copyright 2015 [CoverMyMeds](https://www.covermymeds.com/) and released under the terms of the [MIT License](http://opensource.org/licenses/MIT).
