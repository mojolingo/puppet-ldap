class { 'ldap::client':
  uri      => 'ldaps:///',
  base     => 'dc=foo,dc=bar',
  ssl      => true,
  ssl_cert => 'master-ldap.client.pem',
}

class { 'ldap::server::master':
  suffix          => 'dc=foo,dc=bar',
  rootpw          => 'password',
  schema_inc      => ['ppolicy'],
  modules_inc     => ['ppolicy', 'syncprov'],
  index_inc       => ['mail pres'],
  syncprov        => true,
  sync_binddn     => 'cn=sync,dc=foo,dc=bar',
  ssl             => true,
  ssl_ca          => 'ca.pem',
  ssl_cert        => 'master-ldap.pem',
  ssl_key         => 'master-ldap.key',
  cnconfig_attrs  => ['olcConcurrency: 1'],
  log_level       => '4',
  bind_anon       => false,
}

ldapdn { 'add database':
  ensure            => present,
  dn                => 'dc=foo,dc=bar',
  attributes        => [
    'dc: foo',
    'objectClass: top',
    'objectClass: dcObject',
    'objectClass: organization',
    'o: Foo Dot Bar',
  ],
  unique_attributes => ['dc', 'o'],
}

ldapdn { "ou users":
  dn                => "ou=users,dc=foo,dc=bar",
  attributes        => [
    'ou: users',
    'objectClass: organizationalUnit'
  ],
  unique_attributes => ["ou"],
  ensure            => present,
  require           => Ldapdn['add database'],
}
