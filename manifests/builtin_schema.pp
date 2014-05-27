define ldap::builtin_schema() {
  include ldap::server::convertschema

  # Create the LDIF file from the conversion script
  exec { "convert_schema_${name}_to_ldif":
    cwd     => $ldap::params::schema_prefix,
    creates => "${ldap::params::schema_prefix}/${name}.ldif",
    command => "${ldap::params::prefix}/convertschema.sh -s ${name}.schema -l ${name}.ldif",
    require => [Package[$ldap::params::server_package], File["${ldap::params::prefix}/convertschema.sh"]],
  }

  exec { "load_schema_${name}":
    cwd     => $ldap::params::schema_prefix,
    command => "/usr/bin/ldapadd -QY EXTERNAL -H ldapi:/// < ${name}.ldif",
    unless  => "/usr/bin/ldapsearch -QY EXTERNAL -H ldapi:/// -b 'cn=schema,cn=config' '(cn=*${name})' | grep 'numEntries: 1'",
    require => Exec["convert_schema_${name}_to_ldif"],
  }
}
