# == Define: ldap::server::database
#
# Puppet module to manage database configuration for
# **OpenLdap**.
#
#
# === Parameters
#
#  [suffix]
#
#    **Required**
#
#  [rootpw]
#
#    **Required**
#
#  [rootdn]
#
#    *Optional* (defaults to 'cn=admin,${suffix}')
#
#  [index_inc]
#
#    *Optional* (defaults to [])
#
#  [syncprov]
#
#    *Optional* (defaults to false)
#
#  [syncprov_checkpoint]
#
#    *Optional* (defaults to '100 10')
#
#  [syncprov_sessionlog]
#
#    *Optional* (defaults to *'100'*)
#
#  [sync_binddn]
#
#    *Optional* (defaults to *'false'*)
#
#  [ensure]
#    *Optional* (defaults to 'present')
#
#
# === Examples
#
# ldap::server::database { 'secondary':
#  suffix      => 'dc=foo,dc=bar',
#  rootpw      => '{SHA}iEPX+SQWIR3p67lj/0zigSWTKHg=',
#  syncprov    => true,
#  sync_binddn => 'cn=sync,dc=foo,dc=bar',
#  index_inc   => [
#    'index memberUid            eq',
#    'index mail                 eq',
#    'index givenName            eq,subinitial',
#    ],
#  }
#
# === Authors
#
# Emiliano Castagnari ecastag@gmail.com (a.k.a. Torian)
#
#
# === Copyleft
#
# Copyleft (C) 2012 Emiliano Castagnari ecastag@gmail.com (a.k.a. Torian)
#
#
define ldap::server::database(
  $suffix,
  $rootpw,
  $rootdn              = "cn=admin,${suffix}",
  $index_inc           = [],
  $syncprov            = false,
  $syncprov_checkpoint = '100 10',
  $syncprov_sessionlog = '100',
  $sync_binddn         = false,
  $master              = false,
) {

  require ldap

  if($master and $syncprov) {
    $readable_by_sync = "by dn.base=\"cn=sync,${suffix}\" read  "
  } else {
    $readable_by_sync = ""
  }

  ldapdn { "database config":
    dn                => $ldap::params::main_db_dn,
    attributes        => [
      "olcAccess: to dn.subtree=\"${suffix}\"  attrs=userPassword,shadowLastChange  ${readable_by_sync}by dn.base=\"gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth\" write  by self write  by anonymous auth  by * none",
      "olcAccess: to dn.subtree=\"${suffix}\"  attrs=objectClass,entry,gecos,homeDirectory,uid,uidNumber,gidNumber,cn,memberUid  ${readable_by_sync}by dn.base=\"gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth\" write  by * read",
      "olcAccess: to dn.subtree=\"${suffix}\"  ${readable_by_sync}by dn.base=\"gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth\" write  by self read  by * read",
      'olcAccess: to *  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage',
      'olcDbCheckpoint: 512 30',
      'olcLastMod: TRUE',
      "olcSuffix: ${suffix}",
      "olcRootDN: ${rootdn}",
      "olcRootPW: ${rootpw}",
    ],
    unique_attributes => [
      'olcAccess',
      'olcDbCheckpoint',
      'olcLastMod',
      'olcSuffix',
      'olcRootDN',
      'olcRootPW',
    ],
    ensure            => present,
  }

  $index_base = $ldap::params::index_base
  $indices = split(inline_template("<%= (@index_base + @index_inc).map { |index| \"olcDbIndex: #{index}\" }.join(';') %>"),';')

  ldapdn { "indices":
    dn                => $ldap::params::main_db_dn,
    attributes        => $indices,
    unique_attributes => [
      'olcDbIndex',
    ],
    ensure            => present,
  }

  if($syncprov) {
    ldapdn { "syncprov_config":
      dn                => "olcOverlay={0}syncprov,${ldap::params::main_db_dn}",
      attributes        => [
        'objectClass: olcOverlayConfig',
        'objectClass: olcSyncProvConfig',
        'olcOverlay: syncprov',
        "olcSpCheckpoint: ${syncprov_checkpoint}",
        "olcSpSessionlog: ${syncprov_sessionlog}",
      ],
      unique_attributes => [
        'olcOverlay',
        'olcSpCheckpoint',
        'olcSpSessionlog',
      ],
      ensure            => present,
      require           => Ldap::Server::Module['syncprov'],
    }
  }

}
