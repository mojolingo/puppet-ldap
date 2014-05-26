class { 'ldap::client':
  uri      => 'ldaps:///',
  base     => 'dc=foo,dc=bar',
  ssl      => true,
  ssl_cert => 'master-ldap.client.pem',
}

class { 'ldap::server::slave':
  suffix        => 'dc=foo,dc=bar',
  rootpw        => 'password',
  schema_inc    => ['ppolicy'],
  modules_inc   => ['ppolicy', 'syncprov'],
  index_inc     => ['index mail pres'],
  sync_provider => 'ldapi:///',
  sync_binddn   => 'cn=sync,dc=foo,dc=bar',
  sync_bindpw   => 'foobar',
  sync_rid      => '123',
  sync_updatedn => 'cn=admin,dc=foo,dc=bar',
  ssl           => true,
  ssl_ca        => 'ca.pem',
  ssl_cert      => 'master-ldap.pem',
  ssl_key       => 'master-ldap.key',
  log_level     => '4',
}
