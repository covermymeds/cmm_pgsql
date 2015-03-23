# Determine replication status for postgres instances
# fact set by this script:
#  - $::pg_ismaster
#  - $::pg_failover

require 'facter'
psql_bin = '/usr/bin/psql'

if File.file?(psql_bin)
  version = `#{psql_bin} --version`
  .chomp
  .match(/(\d\.\d+)(\.\d+)?/)[1]

  pg_data = "/var/lib/pgsql/#{version}/data"
  if Dir.exist?(pg_data)
    # Yes we are a postgres server

    # recovery.conf existence signals we are
    # actively replicating from a master
    Facter.add('pg_ismaster') do
      setcode do
        not File.file?("#{pg_data}/recovery.conf")
      end
    end

    # failover.txt existence means we are
    # currently in an active failover activity
    Facter.add('pg_failover') do
      setcode do
        File.file?("#{pg_data}/failover.txt")
      end
    end
  end
end
