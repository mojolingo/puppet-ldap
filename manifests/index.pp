define ldap::index() {
  include ldap

  define index() {
    ldapdn { "${name} index":
      dn          => "olcDatabase={1}bdb,cn=config",
      attributes  => [
        "olcDbIndex: ${name}"
      ],
      ensure      => present,
    }
  }
}
