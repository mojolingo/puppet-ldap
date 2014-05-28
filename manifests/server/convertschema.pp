class ldap::server::convertschema() {

  file { $ldap::params::prefix:
    owner   => $ldap::params::server_owner,
    group   => $ldap::params::server_group,
    ensure  => directory,
  }

  # Upload the conversion script for the schemas
  file { "${ldap::params::prefix}/convertschema.sh":
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    source  => 'puppet:///modules/ldap/convertschema.sh',
    require => File[$ldap::params::prefix],
  }

}
