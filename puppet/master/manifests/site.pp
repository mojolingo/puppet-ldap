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
  index_inc       => ['title pres'],
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

ldapdn { "test user":
  dn                      => "uid=testuser,ou=users,dc=foo,dc=bar",
  attributes              => [
    'objectClass: top',
    'objectClass: person',
    'objectClass: organizationalPerson',
    'objectClass: inetOrgPerson',
    'cn: Joe Bloggs',
    'sn: Bloggs',
    'uid: someuser',
    'givenName: Joe',
    'mail: foo@bar.com',
    'userPassword: {ssha}YlANix4RcH5rySCWSmzoSzbvj2hzb21lc2FsdA==', # somepassword
  ],
  unique_attributes       => [
    'uid',
    'cn',
    'sn',
    'givenName',
    'mail',
    'userPassword',
  ],
  indifferent_attributes  => ["userPassword"],
  ensure                  => present,
  require                 => Ldapdn['ou users'],
}
