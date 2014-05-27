define ldap::index() {
  include ldap

  ldapdn { "${name} index":
    dn          => "olcDatabase={1}bdb,cn=config",
    attributes  => [
      "olcDbIndex: ${name}"
    ],
    ensure      => present,
  }
}
