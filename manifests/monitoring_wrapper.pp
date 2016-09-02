# == Class cmm_pgsql::monitoring_wrapper
#
# Setup monitoring for postgresql servers
#  - this is a wrapper to translate the hieradata structure
#    into the structure required by ::monitoring::target::service
#  - See README.md for data structure examples
#

define cmm_pgsql::monitoring_wrapper (
  $monitor_description  = $title,
  $monitor_command      = 'check_postgresql',
  $monitor_contacts     = hiera('cmm_pgsql::monitoring_wrapper::monitor_contacts', undef),
  $monitor_args         = undef,
  $notes_url            = undef,
) {

  ::monitoring::target::service {"${monitor_description}-${::hostname}":
    command   => "${monitor_command}! $monitor_args",
    notes_url => $notes_url,
    contacts  => $monitor_contacts,
  }

}
