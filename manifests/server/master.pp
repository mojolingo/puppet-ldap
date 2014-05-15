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
    ensure     => running,
    enable     => true,
    pattern    => $ldap::params::server_pattern,
    require    => [
      Package[$ldap::params::server_package],
      Exec['slapd-config-convert'],
      ],
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

  file { "${ldap::params::prefix}/${ldap::params::server_config}":
    ensure  => $ensure,
    content => template("ldap/${ldap::params::prefix}/${ldap::params::server_config}.erb"),
    notify  => Exec['slapd-config-convert'],
    require => $ssl ? {
      false => [
        Package[$ldap::params::server_package],
        ],
      true  => [
        Package[$ldap::params::server_package],
        File['ssl_ca'],
        File['ssl_cert'],
        File['ssl_key'],
        ]
      }
  }

  exec { "slapd-config-convert":
    command     => "/bin/sh -c 'rm -rf ${ldap::params::prefix}/slapd.d/* && rm -rf ${ldap::params::db_prefix}/* && /usr/sbin/slaptest -n 0 -f ${ldap::params::prefix}/${ldap::params::server_config} -F ${ldap::params::prefix}/slapd.d/ && /bin/chown -R ${ldap::params::server_owner}:${ldap::params::server_group} ${ldap::params::prefix}/slapd.d'",
    refreshonly => true,
    notify      => Service[$ldap::params::service],
    user        => $ldap::params::server_owner,
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

