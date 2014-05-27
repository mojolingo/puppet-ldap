
class ldap::params {

  case $::osfamily {

    'Debian' : {

      $package   = [ 'ldap-utils' ]

      $prefix    = '/etc/ldap'
      $owner     = 'root'
      $group     = 'root'
      $config    = 'ldap.conf'
      $cacertdir = '/etc/ssl/certs'

      $service         = 'slapd'
      $server_pattern  = 'slapd'
      $server_package  = [ 'slapd' ]
      $server_config   = 'slapd.conf'
      $server_owner    = 'openldap'
      $server_group    = 'openldap'
      $db_prefix       = '/var/lib/ldap'
      $ssl_prefix      = '/etc/ssl/certs'
      $server_run      = '/var/run/slapd'

      case $::operatingsystemmajrelease {
        5 : {

          case $::architecture {
            /^amd64/: {
              $module_prefix = '/usr/lib64/ldap'
            }

            /^i?[346]86/: {
              $module_prefix = '/usr/lib/ldap'
            }

            default: {
              fail("Architecture not supported (${::architecture})")
            }

          }

        }

        default : {
              $module_prefix = '/usr/lib/ldap'
        }

      }

      $modules_base  = [ 'back_bdb' ]

      $schema_prefix   = "${prefix}/schema"
      $schema_base     = [ 'core', 'cosine', 'nis', 'inetorgperson', ]
      $index_base      = [
        'objectClass eq',
        'entryCSN     eq',
        'entryUUID    eq',
        'uidNumber    eq',
        'gidNumber    eq',
        'cn           pres,sub,eq',
        'sn           pres,sub,eq',
        'uid          pres,sub,eq',
        'displayName  pres,sub,eq',
        ]

      $cnconfig_default_attrs = [
        'olcConfigFile',
        'olcConfigDir',
        'olcAllows',
        'olcAttributeOptions',
        'olcAuthzPolicty',
        'olcConcurrency',
        'olcConnMaxPending',
        'olcConnMaxPendingAuth',
        'olcGentleHUP',
        'olcIdleTimeout',
        'olcIndexSubstrIfMaxLen',
        'olcIndexSubstrIfMinLen',
        'olcIndexSubstrIfAnyLen',
        'olcIndexSubstrIfAnyStep',
        'olcIndexIntLen',
        'olcLocalSSF',
        'olcLogLevel',
        'olcPidFile',
        'olcReadOnly',
        'olcReverseLookup',
        'olcSaslSecProps',
        'olcSockbufMaxIncoming',
        'olcSockbufMaxIncomingAuth',
        'olcTLSCACertificateFile',
        'olcTLSCertificateKeyFile',
        'olcTLSCertificateFile',
        'olcTLSVerifyClient',
        'olcThreads',
        'olcToolThreads',
        'olcWriteTimeout',
      ]

    }

    'RedHat' : {

      $package   = [ 'openldap', 'openldap-clients' ]

      $prefix    = '/etc/openldap'
      $owner     = 'root'
      $group     = 'root'
      $config    = 'ldap.conf'

      $server_package  = [ 'openldap-servers' ]
      $server_config   = 'slapd.conf'

      case $::operatingsystemmajrelease {
        5 : {
          $service   = 'ldap'
          $cacertdir = '/etc/openldap/cacerts'
          $ssl_prefix = '/etc/openldap/cacerts'
        }

        default : {
          $service   = 'slapd'
          $cacertdir = '/etc/openldap/certs'
          $ssl_prefix = '/etc/openldap/certs'
        }

      }
      $server_pattern  = 'slapd'
      $server_owner    = 'ldap'
      $server_group    = 'ldap'

      $schema_prefix   = "${prefix}/schema"
      $db_prefix     = '/var/lib/ldap'

      case $::architecture {
        /^x86_64/: {
          $module_prefix = '/usr/lib64/openldap'
        }

        /^i?[346]86/: {
          $module_prefix = '/usr/lib/openldap'
        }

        default: {
          fail("Architecture not supported (${::architecture})")
        }
      }

      case $::operatingsystem {

        /(?i:OVS)/ : {
          $schema_base   = [ 'core', 'cosine', 'nis', 'inetorgperson', 'authldap' ]
          $modules_base  = [ 'back_bdb' ]
        }

        default : {
          $schema_base   = [ 'core', 'cosine', 'nis', 'inetorgperson', ]
          $modules_base  = [ 'back_bdb' ]
        }

      }

      $server_run    = '/var/run/openldap'
      $index_base    = [
        'objectClass eq',
        'entryCSN     eq',
        'entryUUID    eq',
        'uidNumber    eq',
        'gidNumber    eq',
        'cn           pres,sub,eq',
        'sn           pres,sub,eq',
        'uid          pres,sub,eq',
        'displayName  pres,sub,eq',
        ]

      $cnconfig_default_attrs = [
        'olcConfigFile',
        'olcConfigDir',
        'olcAllows',
        'olcAttributeOptions',
        'olcAuthzPolicty',
        'olcConcurrency',
        'olcConnMaxPending',
        'olcConnMaxPendingAuth',
        'olcGentleHUP',
        'olcIdleTimeout',
        'olcIndexSubstrIfMaxLen',
        'olcIndexSubstrIfMinLen',
        'olcIndexSubstrIfAnyLen',
        'olcIndexSubstrIfAnyStep',
        'olcIndexIntLen',
        'olcLocalSSF',
        'olcLogLevel',
        'olcPidFile',
        'olcReadOnly',
        'olcReverseLookup',
        'olcSaslSecProps',
        'olcSockbufMaxIncoming',
        'olcSockbufMaxIncomingAuth',
        'olcTLSCACertificateFile',
        'olcTLSCertificateKeyFile',
        'olcTLSCertificateFile',
        'olcTLSVerifyClient',
        'olcThreads',
        'olcToolThreads',
        'olcWriteTimeout',
      ]
    }

    'Suse' : {
      $package   = [ 'openldap2-client' ]

      $prefix    = '/etc/openldap'
      $owner     = 'root'
      $group     = 'root'
      $config    = 'ldap.conf'
      $cacertdir = '/etc/ssl/certs'

      $server_package  = [ 'openldap2' ]
      $server_config   = 'slapd.conf'
      $service         = 'ldap'
      $server_script   = 'ldap'
      $server_pattern  = 'slapd'
      $server_owner    = 'root'
      $server_group    = 'ldap'

      $schema_prefix   = "${prefix}/schema"
      $db_prefix     = '/var/lib/ldap'

      case $::architecture {
        /^x86_64/: {
          $module_prefix = '/usr/lib/openldap'
        }

        /^i?[346]86/: {
          $module_prefix = '/usr/lib/openldap'
        }

        default: {
          fail("Architecture not supported (${::architecture})")
        }
      }

      $ssl_prefix    = '/etc/ssl/certs'
      $server_run    = '/var/run/slapd'
      $schema_base   = [ 'core', 'cosine', 'nis', 'inetorgperson', ]
      $modules_base  = [ 'back_bdb' ]
      $index_base    = [
        'objectClass eq',
        'entryCSN     eq',
        'entryUUID    eq',
        'uidNumber    eq',
        'gidNumber    eq',
        'cn           pres,sub,eq',
        'sn           pres,sub,eq',
        'uid          pres,sub,eq',
        'displayName  pres,sub,eq',
        ]

      $cnconfig_default_attrs = [
        'olcConfigFile',
        'olcConfigDir',
        'olcAllows',
        'olcAttributeOptions',
        'olcAuthzPolicty',
        'olcConcurrency',
        'olcConnMaxPending',
        'olcConnMaxPendingAuth',
        'olcGentleHUP',
        'olcIdleTimeout',
        'olcIndexSubstrIfMaxLen',
        'olcIndexSubstrIfMinLen',
        'olcIndexSubstrIfAnyLen',
        'olcIndexSubstrIfAnyStep',
        'olcIndexIntLen',
        'olcLocalSSF',
        'olcLogLevel',
        'olcPidFile',
        'olcReadOnly',
        'olcReverseLookup',
        'olcSaslSecProps',
        'olcSockbufMaxIncoming',
        'olcSockbufMaxIncomingAuth',
        'olcTLSCACertificateFile',
        'olcTLSCertificateKeyFile',
        'olcTLSCertificateFile',
        'olcTLSVerifyClient',
        'olcThreads',
        'olcToolThreads',
        'olcWriteTimeout',
      ]

    }

    default:  {
      fail("Operating system ${::operatingsystem} not supported")
    }

  }

}

