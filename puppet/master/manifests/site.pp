class { 'ldap::server::master':
  suffix      => 'dc=foo,dc=bar',
  rootpw      => 'password',
  schema_inc  => ['ppolicy'],
}
