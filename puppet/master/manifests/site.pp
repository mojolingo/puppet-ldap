class { 'ldap::server::master':
  suffix      => 'dc=foo,dc=bar',
  rootpw      => 'password',
  schema_inc  => ['ppolicy'],
  modules_inc => ['ppolicy', 'syncprov'],
  index_inc   => ['index mail pres'],
  syncprov    => true,
  sync_binddn => 'cn=sync,dc=foo,dc=bar',
}
