define ldap::builtin_schema() {
  exec { "load_schema_${name}":
    cwd     => $ldap::params::schema_prefix,
    command => "/usr/bin/ldapadd -QY EXTERNAL -H ldapi:/// < ${name}.ldif",
    unless  => "/usr/bin/ldapsearch -QY EXTERNAL -H ldapi:/// -b 'cn=schema,cn=config' '(cn=*${name})' | grep 'numEntries: 1'",
  }
}
