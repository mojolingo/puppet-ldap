define ldap::module() {
  include ldap

  ldapdn { "${name} module config":
    dn          => "cn=module{0},cn=config",
    attributes  => [
      "olcModuleLoad: ${name}"
    ],
    ensure      => present,
    require     => Ldapdn['module config'],
  }
}
