# == Class: ldap::server::master
#
# Puppet module to manage server configuration for
# **OpenLdap**.
#
#
# === Parameters
#
#  [suffix]
#
#    **Required**
#
#  [rootpw]
#
#    **Required**
#
#  [rootdn]
#
#    *Optional* (defaults to 'cn=admin,${suffix}')
#
#  [schema_inc]
#
#    *Optional* (defaults to [])
#
#  [modules_inc]
#
#    *Optional* (defaults to [])
#
#  [index_inc]
#
#    *Optional* (defaults to [])
#
#  [cnconfig_attrs]
#    Default cn=config attributes that needs to be changed
#    upon runs. An array of attributes as key-value pairs.
#    eg. ['olcConcurrency: 1']
#    *Optional* (defaults to [])
#
#  [log_level]
#
#    *Optional* (defaults to 0)
#
#  [bind_anon]
#
#    *Optional* (defaults to true)
#
#  [ssl]
#
#    *Requires*: ssl_{cert,ca,key} parameter
#    *Optional* (defaults to false)
#
#  [ssl_cert]
#
#    *Optional* (defaults to false)
#
#  [ssl_ca]
#
#    *Optional* (defaults to false)
#
#  [ssl_key]
#
#    *Optional* (defaults to false)
#
#  [syncprov]
#
#    *Optional* (defaults to false)
#
#  [syncprov_checkpoint]
#
#    *Optional* (defaults to '100 10')
#
#  [syncprov_sessionlog]
#
#    *Optional* (defaults to *'100'*)
#
#  [sync_binddn]
#
#    *Optional* (defaults to *'false'*)
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
class ldap::server::master(
  $suffix,
  $rootpw,
  $rootdn              = "cn=admin,${suffix}",
  $schema_inc          = [],
  $modules_inc         = [],
  $index_inc           = [],
  $cnconfig_attrs      = [],
  $log_level           = '0',
  $bind_anon           = true,
  $ssl                 = false,
  $ssl_ca              = false,
  $ssl_cert            = false,
  $ssl_key             = false,
  $syncprov            = false,
  $syncprov_checkpoint = '100 10',
  $syncprov_sessionlog = '100',
  $sync_binddn         = false,
  $enable_motd         = false,
  $ensure              = present) {

  require ldap

  if($enable_motd) {
    motd::register { 'ldap::server::master': }
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
    dn                => $ldap::params::main_db_dn,
    attributes        => [
      'olcAccess: to *  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage',
      'olcAccess: to dn.subtree="dc=foo,dc=bar"  attrs=userPassword,shadowLastChange  by dn.base="cn=sync,dc=foo,dc=bar" read  by self write  by anonymous auth  by * none',
      'olcAccess: to dn.subtree="dc=foo,dc=bar"  attrs=objectClass,entry,gecos,homeDirectory,uid,uidNumber,gidNumber,cn,memberUid  by dn.base="cn=sync,dc=foo,dc=bar" read  by * read',
      'olcAccess: to dn.subtree="dc=foo,dc=bar"  by dn.base="cn=sync,dc=foo,dc=bar" read  by self read  by * read',
      'olcDbCheckpoint: 512 30',
      'olcLastMod: TRUE',
      "olcSuffix: ${suffix}",
      "olcRootDN: ${rootdn}",
      "olcRootPW: ${rootpw}",
    ],
    unique_attributes => [
      'olcAccess',
      'olcDbCheckpoint',
      'olcLastMod',
      'olcSuffix',
      'olcRootDN',
      'olcRootPW',
    ],
    ensure            => present,
  }

  ldapdn { "module config":
    dn                => "cn=module{0},cn=config",
    attributes        => [
      'objectClass: olcModuleList',
      'cn: module{0}',
      "olcModulePath: ${ldap::params::module_prefix}",
    ],
    unique_attributes => ['olcModulePath'],
    ensure            => present,
  }

  ldap::index { $ldap::params::index_base: }
  ldap::index { $index_inc: }

  ldap::module { $ldap::params::modules_base: }
  ldap::module { $modules_inc: }

  ldap::builtin_schema { $ldap::params::schema_base: }
  ldap::builtin_schema { $schema_inc: }

  if($syncprov) {
    ldapdn { "syncprov_config":
      dn                => "olcOverlay={0}syncprov,${ldap::params::main_db_dn}",
      attributes        => [
        'objectClass: olcOverlayConfig',
        'objectClass: olcSyncProvConfig',
        'olcOverlay: syncprov',
        "olcSpCheckpoint: ${syncprov_checkpoint}",
        "olcSpSessionLog: ${syncprov_sessionlog}",
      ],
      unique_attributes => [
        'olcOverlay',
        'olcSpCheckpoint',
        'olcSpSessionlog',
      ],
      ensure            => present,
    }
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
  }

  ldapdn { "cnconfig_attrs":
    dn                => "cn=config",
    attributes        => $cnconfig_attrs,
    unique_attributes => $ldap::params::cnconfig_default_attrs,
    ensure            => present,
  }

  if(!$bind_anon) {
    ldapdn { "disallow_bind_anon":
      dn          => "cn=config",
      attributes  => [
        'olcDisallows: bind_anon',
      ],
      ensure      => present,
    }
  }

  File {
    mode  => '0640',
    owner => $ldap::params::server_owner,
    group => $ldap::params::server_group,
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
      path     => [ "/bin", "/usr/bin", "/sbin", "/usr/sbin" ]
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

