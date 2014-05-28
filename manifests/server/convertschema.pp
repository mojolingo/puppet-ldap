class ldap::server::convertschema() {

  # Upload the conversion script for the schemas
  file { "${ldap::params::prefix}/convertschema.sh":
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    source  => 'puppet:///modules/ldap/convertschema.sh',
    require => File[$ldap::params::prefix],
  }

}
