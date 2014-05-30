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
  require           => Class['ldap::server::master'],
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
    'uid: testuser',
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

# Secondary database

ldap::server::database { '{2}bdb':
  suffix          => 'dc=doo,dc=dah',
  rootpw          => 'otherpassword',
  index_inc       => ['title pres'],
  syncprov        => true,
  sync_binddn     => 'cn=sync,dc=doo,dc=dah',
  master          => true,
}

ldapdn { 'add secondary database':
  ensure            => present,
  dn                => 'dc=doo,dc=dah',
  attributes        => [
    'dc: doo',
    'objectClass: top',
    'objectClass: dcObject',
    'objectClass: organization',
    'o: Doo Dot Dah',
  ],
  unique_attributes => ['dc', 'o'],
  require           => Ldap::Server::Database['{2}bdb'],
}

ldapdn { "secondary - ou users":
  dn                => "ou=users,dc=doo,dc=dah",
  attributes        => [
    'ou: users',
    'objectClass: organizationalUnit'
  ],
  unique_attributes => ["ou"],
  ensure            => present,
  require           => Ldapdn['add secondary database'],
}

ldapdn { "secondary - test user":
  dn                      => "uid=testuser,ou=users,dc=doo,dc=dah",
  attributes              => [
    'objectClass: top',
    'objectClass: person',
    'objectClass: organizationalPerson',
    'objectClass: inetOrgPerson',
    'cn: Joe Bloggs',
    'sn: Bloggs',
    'uid: testuser',
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
  require                 => Ldapdn['secondary - ou users'],
}
