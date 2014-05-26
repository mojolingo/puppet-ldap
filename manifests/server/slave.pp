# == Class: ldap::server::slave
#
# Puppet module to manage server configuration for
# **OpenLdap**.
#
#
# === Parameters
#
#  [suffix]
#    Ldap tree base
#    **Required**
#
#  [sync_rid]
#    Replica ID (numeric)
#    **Required**
#
#  [sync_provider]
#    Provider URI (ldap[s]://master.ldap)
#    **Required**
#
#  [sync_updatedn]
#    DN permitted to update the replica (should not be the same as rootdn)
#    **Required**
#
#  [sync_binddn]
#    DN that will perform sync (connect to master and fetch data)
#    **Required**
#
#  [sync_bindpw]
#    Credentials fr sync_binddn.
#    **NOTE** This should be in clear text
#    **Required**
#
#  [rootpw]
#    Password for root DN (encrypted as in 'slappasswd -h "{SHA}" -s example')
#    **Required**
#
#  [rootdn]
#    Root DN.
#    *Optional* (defaults to 'cn=admin,${suffix}')
#
#  [schema_inc]
#    Array of additional schemas that will be included.
#    Some schemas are already included (ldap::params::schemas_base)
#    'core', 'cosine', 'nis', 'inetorgperson'
#    *Optional* (defaults to [])
#
#  [modules_inc]
#    Array of modules that you want to load. Depends on the ditro being used.
#    Some modules are already included through ldap::params::modules_base
#    *Optional* (defaults to [])
#
#  [index_inc]
#    Array of indexes to be generated.
#    Some indexes are already generated through ldap::params::index_base
#         'index objectclass  eq',
#         'index entryCSN     eq',
#         'index entryUUID    eq',
#         'index uidNumber    eq',
#         'index gidNumber    eq',
#         'index cn           pres,sub,eq',
#         'index sn           pres,sub,eq',
#         'index uid          pres,sub,eq',
#         'index displayName  pres,sub,eq',
#    *Optional* (defaults to [])
#
#  [cnconfig_attrs]
#    Default cn=config attributes that needs to be changed
#    upon runs. An array of attributes as key-value pairs.
#    eg. ['olcConcurrency: 1']
#    *Optional* (defaults to [])
#
#  [log_level]
#    OpenLdap server log level.
#    *Optional* (defaults to 0)
#
#  [bind_anon]
#    Allow anonymous binding
#    *Optional* (defaults to true)
#
#  [ssl]
#    Enable SSL/TLS.
#    *Requires*: ssl_{cert,ca,key} parameter
#    *Optional* (defaults to false)
#
#  [ssl_cert]
#    Public certificate filename (should be located at puppet:///files/ldap)
#    *Requires*: ssl => true
#    *Optional* (defaults to false)
#
#  [ssl_ca]
#    CA certificate filename (should be located at puppet:///files/ldap)
#    *Requires*: ssl => true
#    *Optional* (defaults to false)
#
#  [ssl_key]
#    Private certificate filename (should be located at puppet:///files/ldap)
#    *Requires*: ssl => true
#    *Optional* (defaults to false)
#
#  [sync_type]
#    Content synchronizatin protocol type (refreshOnly / refreshAndPersist)
#    *Optional* (defaults to refreshOnly)
#
#  [sync_interval]
#    Synchronization interval.
#    *Optional* (defaults to 00:00:10:00)
#
#  [sync_base]
#    Base for replication
#    *Optional* (defaults to '')
#
#  [sync_filter]
#    Filter to use when fetching content.
#    *Optional* (defaults to '(ObjectClass=*)')
#
#  [sync_attrs]
#    Attributes to synchronize.
#    *Optional* (defaults to '*')
#
#  [sync_scope]
#    Objects search depth.
#    *Optional* (defaults to 'sub')
#
#  [enable_motd]
#    Use motd to report the usage of this module.
#    *Requires*: https://github.com/torian/puppet-motd.git
#    *Optional* (defaults to false)
#
#  [ensure]
#    *Optional* (defaults to 'present')
#
#
# == Tested/Works on:
#   - Debian:    5.0   / 6.0   / 7.x
#   - RHEL       5.x   / 6.x
#   - CentOS     5.x   / 6.x
#   - OpenSuse:  11.x  / 12.x
#   - OVS:       2.1.1 / 2.1.5 / 2.2.0 / 3.0.2
#
#
# === Examples
#
# class { 'ldap::server::master':
#  suffix      => 'dc=foo,dc=bar',
#  rootpw      => '{SHA}iEPX+SQWIR3p67lj/0zigSWTKHg=',
#  syncprov    => true,
#  sync_binddn => 'cn=sync,dc=foo,dc=bar',
#  modules_inc => [ 'syncprov' ],
#  schema_inc  => [ 'gosa/samba3', 'gosa/gosystem' ],
#  index_inc   => [
#  'index memberUid            eq',
#    'index mail                 eq',
#    'index givenName            eq,subinitial',
#    ],
#  }
#
# === Authors
#
# Emiliano Castagnari ecastag@gmail.com (a.k.a. Torian)
#
#
# === Copyleft
#
# Copyleft (C) 2012 Emiliano Castagnari ecastag@gmail.com (a.k.a. Torian)
#
#
class ldap::server::slave(
  $suffix,
  $sync_rid,
  $sync_provider,
  $sync_updatedn,
  $sync_binddn,
  $sync_bindpw,
  $rootpw,
  $rootdn         = "cn=admin,${suffix}",
  $schema_inc     = [],
  $modules_inc    = [],
  $index_inc      = [],
  $cnconfig_attrs = [],
  $log_level      = '0',
  $bind_anon      = true,
  $ssl            = false,
  $ssl_ca         = false,
  $ssl_cert       = false,
  $ssl_key        = false,
  $sync_type      = 'refreshOnly',
  $sync_interval  = '00:00:10:00',
  $sync_base      = $suffix,
  $sync_filter    = '(objectClass=*)',
  $sync_attrs     = '*',
  $sync_scope     = 'sub',
  $enable_motd    = false,
  $ensure         = 'present') {

  require ldap

  if($enable_motd) {
    motd::register { 'ldap::server::slave': }
  }

  file { ['/var/cache/local', '/var/cache/local/preseeding']:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
  }

  file { "/var/cache/local/preseeding/slapd.seed":
    ensure  => present,
    content => template("ldap/slapd.seed.erb"),
    owner   => 'root',
    group   => 'root',
  }

  package { $ldap::params::server_package:
    ensure        => $ensure,
    responsefile  => "/var/cache/local/preseeding/slapd.seed",
  }

  service { $ldap::params::service:
    ensure  => running,
    enable  => true,
    pattern => $ldap::params::server_pattern,
    require => [
      Package[$ldap::params::server_package],
    ],
  }

  ldapdn { "database config":
    dn                => "olcDatabase={1}bdb,cn=config",
    attributes        => [
      'olcAccess: to *  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage',
      'olcAccess: to dn.subtree="dc=foo,dc=bar"  attrs=userPassword,shadowLastChange  by self write  by anonymous auth  by * none',
      'olcAccess: to dn.subtree="dc=foo,dc=bar"  attrs=objectClass,entry,gecos,homeDirectory,uid,uidNumber,gidNumber,cn,memberUid  by * read',
      'olcAccess: to dn.subtree="dc=foo,dc=bar"  by self read  by * read',
      'olcDbIndex: objectClass eq',
      'olcDbIndex: entryCSN eq',
      'olcDbIndex: entryUUID eq',
      'olcDbIndex: uidNumber eq',
      'olcDbIndex: gidNumber eq',
      'olcDbIndex: cn pres,eq,sub',
      'olcDbIndex: sn pres,eq,sub',
      'olcDbIndex: uid pres,eq,sub',
      'olcDbIndex: displayName pres,eq,sub',
      'olcDbIndex: mail pres',
      'olcLastMod: TRUE',
      "olcRootPW: ${rootpw}",
    ],
    unique_attributes => [
      'olcAccess',
      'olcLastMod',
      'olcRootPW',
    ],
    ensure            => present,
  }

  ldapdn { "module config":
    dn                => "cn=module{0},cn=config",
    attributes        => [
      "olcModulePath: ${ldap::params::module_prefix}",
    ],
    unique_attributes => ['olcModulePath'],
    ensure            => present,
  }

  ldap::module { $ldap::params::modules_base: }
  ldap::module { $modules_inc: }

  ldap::builtin_schema { $ldap::params::schema_base: }
  ldap::builtin_schema { $schema_inc: }

  ldapdn { "syncrepl":
    dn                => "olcDatabase={1}bdb,cn=config",
    attributes        => [
      "olcSyncrepl: rid=${sync_rid} provider=${sync_provider} bindmethod=simple timeout=0 network-timeout=0 binddn=\"${sync_binddn}\" credentials=\"${sync_bindpw}\" keepalive=0:0:0 starttls=no filter=\"${sync_filter}\" searchbase=\"${sync_base}\" scope=${sync_scope} attrs=\"${sync_attrs}\" schemachecking=off type=${sync_type} interval=${sync_interval} retry=undefined",
      "olcLimits: dn.exact=\"${sync_binddn}\" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited",
    ],
    unique_attributes => [
      'olcLimits',
      'olcSyncrepl',
    ],
    ensure            => present,
  }

  ldapdn { "updateref":
    dn                => "olcDatabase={1}bdb,cn=config",
    attributes        => [
      "olcUpdateRef: ${sync_provider}",
    ],
    unique_attributes => [
      'olcUpdateRef',
    ],
    ensure            => present,
    require           => Ldapdn['syncrepl'],
  }

  ldapdn { "global confg":
    dn                => "cn=config",
    attributes        => [
      "olcArgsFile: ${ldap::params::server_run}/slapd.args",
      "olcLogLevel: ${log_level}",
      "olcPidFile: ${ldap::params::server_run}/slapd.pid",
    ],
    unique_attributes => $ldap::params::cnconfig_default_attrs,
    ensure            => present,
    notify            => Service[$ldap::params::service],
  }

  ldapdn { "cnconfig_attrs":
    dn                => "cn=config",
    attributes        => $cnconfig_attrs,
    unique_attributes => $ldap::params::cnconfig_default_attrs,
    ensure            => present,
  }

  File {
    mode    => '0640',
    owner   => $ldap::params::server_owner,
    group   => $ldap::params::server_group,
  }

  $msg_prefix = 'SSL enabled. You must specify'
  $msg_suffix = '(filename). It should be located at puppet:///files/ldap'

  if($ssl) {

    if(!$ssl_ca) { fail("${msg_prefix} ssl_ca ${msg_suffix}") }
    file { 'ssl_ca':
      ensure  => present,
      source  => "puppet:///files/ldap/${ssl_ca}",
      path    => "${ldap::params::ssl_prefix}/${ssl_ca}",
      mode    => '0644',
    }

    if(!$ssl_cert) { fail("${msg_prefix} ssl_cert ${msg_suffix}") }
    file { 'ssl_cert':
      ensure  => present,
      source  => "puppet:///files/ldap/${ssl_cert}",
      path    => "${ldap::params::ssl_prefix}/${ssl_cert}",
      mode    => '0644',
    }

    if(!$ssl_key) { fail("${msg_prefix} ssl_key ${msg_suffix}") }
    file { 'ssl_key':
      ensure  => present,
      source  => "puppet:///files/ldap/${ssl_key}",
      path    => "${ldap::params::ssl_prefix}/${ssl_key}",
    }

    # Create certificate hash file
    exec { 'Server certificate hash':
      command  => "ln -s ${ldap::params::ssl_prefix}/${ssl_cert} ${ldap::params::cacertdir}/$(openssl x509 -noout -hash -in ${ldap::params::ssl_prefix}/${ssl_cert}).0",
      unless   => "test -f ${ldap::params::cacertdir}/$(openssl x509 -noout -hash -in ${ldap::params::ssl_prefix}/${ssl_cert}).0",
      provider => $::puppetversion ? {
                    /^3./   => 'shell',
                    /^2.7/  => 'shell',
                    /^2.6/  => 'posix',
                    default => 'posix'
                  },
      require  => File['ssl_cert'],
      path    => [ "/bin", "/usr/bin", "/sbin", "/usr/sbin" ]
    }

    ldapdn { "SSL config":
      dn                => "cn=config",
      attributes        => [
        "olcTLSCACertificateFile: ${ldap::params::ssl_prefix}/${ssl_ca}",
        "olcTLSCertificateFile: ${ldap::params::ssl_prefix}/${ssl_cert}",
        "olcTLSCertificateKeyFile: ${ldap::params::ssl_prefix}/${ssl_key}",
      ],
      unique_attributes => $ldap::params::cnconfig_default_attrs,
      ensure            => present,
      require           => [File['ssl_ca'], File['ssl_cert'], File['ssl_key'], Exec['Server certificate hash']],
      notify            => Service[$ldap::params::service],
    }

  }

  # Additional configurations (for rc scripts)
  case $::osfamily {

    'Debian' : {
      class { 'ldap::server::debian': ssl => $ssl }
    }

    'RedHat' : {
      class { 'ldap::server::redhat': ssl => $ssl }
    }

    #'Suse' : {
    #  class { 'ldap::server::suse':   ssl => $ssl }
    #}

  }

}

# vim: ts=4
