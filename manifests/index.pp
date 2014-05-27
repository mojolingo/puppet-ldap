define ldap::index() {
  include ldap

  ldapdn { "${name} index":
    dn          => $ldap::params::main_db_dn,
    attributes  => [
      "olcDbIndex: ${name}"
    ],
    ensure      => present,
  }
}
