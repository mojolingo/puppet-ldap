Puppet OpenLDAP Module
======================

Introduction
------------

Puppet module to manage client and server configuration for
**OpenLdap**.

## Usage ##

### Ldap client ###

Ldap client configuration at its simplest:


    class { 'ldap':
    	uri  => 'ldap://ldapserver00 ldap://ldapserver01',
    	base => 'dc=foo,dc=bar'
    }


Enable TLS/SSL:

Note that *ssl_cert* should be the CA's certificate file, and
it should be located under *puppet:///files/ldap/*.

    class { 'ldap':
    	uri      => 'ldap://ldapserver00 ldap://ldapserver01',
    	base     => 'dc=foo,dc=bar',
    	ssl      => true,
    	ssl_cert => 'ldapserver.pem'
    }

Enable nsswitch and pam configuration (requires both modules):

    class { 'ldap':
      uri      => 'ldap://ldapserver00 ldap://ldapserver01',
      base     => 'dc=foo,dc=bar',
      ssl      => true
      ssl_cert => 'ldapserver.pem',

      nsswitch   => true,
      nss_passwd => 'ou=users',
      nss_shadow => 'ou=users',
      nss_group  => 'ou=groups',

      pam        => true,
    }

### OpenLdap Server ###

#### Master server ####

OpenLdap server as simple as it is:

    class { 'ldap::server::master':
      suffix      => 'dc=foo,dc=bar',
      rootpw      => '{SHA}iEPX+SQWIR3p67lj/0zigSWTKHg=',
    }

Configure an OpenLdap master with syncrepl enabled:

    class { 'ldap::server::master':
      suffix      => 'dc=foo,dc=bar',
      rootpw      => '{SHA}iEPX+SQWIR3p67lj/0zigSWTKHg=',
      syncprov    => true,
      sync_binddn => 'cn=sync,dc=foo,dc=bar',
      modules_inc => [ 'syncprov' ],
      schema_inc  => [ 'gosa/samba3', 'gosa/gosystem' ],
      index_inc   => [
        'index memberUid            eq',
        'index mail                 eq',
        'index givenName            eq,subinitial',
        ],
    }

With TLS/SSL enabled:

    class { 'ldap::server::master':
      suffix      => 'dc=foo,dc=bar',
      rootpw      => '{SHA}iEPX+SQWIR3p67lj/0zigSWTKHg=',
      ssl         => true,
      ssl_ca      => 'ca.pem',
      ssl_cert    => 'master-ldap.pem',
      ssl_key     => 'master-ldap.key',
    }

*NOTE*: SSL certificates should reside in you puppet master
file repository 'puppet:///files/ldap/'

#### Slave server ####

Configure an OpenLdap slave:

    class { 'ldap::server::slave':
      suffix        => 'dc=foo,dc=bar',
      rootpw        => '{SHA}iEPX+SQWIR3p67lj/0zigSWTKHg=',
      sync_rid      => '1234',
      sync_provider => 'ldap://ldapmaster'
      sync_updatedn => 'cn=admin,dc=foo,dc=bar',
      sync_binddn   => 'cn=sync,dc=foo,dc=bar',
      sync_bindpw   => 'super_secret',
      schema_inc    => [ 'gosa/samba3', 'gosa/gosystem' ],
      index_inc     => [
        'index memberUid            eq',
        'index mail                 eq',
        'index givenName            eq,subinitial',
        ],
    }

### Directory updates

This module includes a puppet type and provider that aims to simply managing ldap entries via ldapmodify and ldapadd commands.

In essence the mechanism it uses is described as follows:

* Translate the puppet "ldapdn" resource into an in-memory ldif
* ldapsearch the existing dn to verify the current contents (if any)
* compare the results of the search with what should be the case
* work out which add/modify/delete commands are required to get to the desired state
* write out an appropriate ldif file
* execute it via an ldapmodify statement.

Examples of usage are as follows:

First you might like to set a root password:

```puppet
ldapdn { "add manager password":
  dn => "olcDatabase={2}hdb,cn=config",
  attributes => ["olcRootPW: password"],
  unique_attributes => ["olcRootPW"],
  ensure => present,
}
```

`attributes` sets the attributes that you wish to set (be sure to separate key and value with <semi-colon space>).
`unique_attributes` can be used to specify the behaviour of `ldapmodify` when there is an existing attribute with this name. If the attribute key is specified here, then `ldapmodify` will issue a replace, replacing the existing value (if any), whereas if the attribute key is not specified here, then `ldapmodify` will simply ensure the attribute exists with the value required, alongside other values if also specified (e.g. for `objectClass`).

```puppet
$organizational_units = ["Groups", "People", "Programs"]
ldap::add_organizational_unit { $organizational_units: }

define ldap::add_organizational_unit () {
  ldapdn { "ou ${name}":
    dn => "ou=${name},dc=example,dc=com",
    attributes => [ "ou: ${name}",
                    "objectClass: organizationalUnit" ],
    unique_attributes => ["ou"],
    ensure => present,
  }
}
```

In the above example, multiple groups are created. Notice in each case, that `objectClass` does not form part of the `unique_attributes`, so that (in future) more `objectClasses` may be added to each ou, without them being replaced.

By default, all ldap commands are issued with the `-QY EXTERNAL` SASL auth mechanism.

Here is how you can create a database in the first place:

```puppet
ldapdn { "add database":
  dn => "dc=example,dc=com",
  attributes => ["dc: example",
                 "objectClass: top",
                 "objectClass: dcObject",
                 "objectClass: organization",
                 "o: example.com"],
  unique_attributes => ["dc", "o"],
  ensure => present
}
```

Additionally, you may need to specify alternative authentication options when managing resources:

```puppet
ldapdn { "add database":
  dn => "dc=example,dc=com",
  attributes => ["dc: example",
                 "objectClass: top",
                 "objectClass: dcObject",
                 "objectClass: organization",
                 "o: example.com"],
  unique_attributes => ["dc", "o"],
  ensure => present,
  auth_opts => ["-xD", "cn=admin,dc=example,dc=com", "-w", "somePassword"],
}
```

Sometimes you will want to ensure an attribute exists, but wont care about its subsequent value. An example of this is a password.

```puppet
ldapdn { "add password":
  dn => "cn=Geoff,ou=Staff,dc=example,dc=com",
  attributes => ["olcUserPassword: {SSHA}somehash..."],
  unique_attributes => ["olcUserPassword"],
  indifferent_attributes => ["olcUserPassword"],
  ensure => present
}
```

By specifying `indifferent_attributes, ensure => present` will ensure that if the key doesn't exist, it will create it with the desired password hash, but if the key does exist, it won't bother replacing it again. In this way you can keep passwords managed by something like phpldapadmin if you so wish.

Notes
-----

Ldap client / server configuration tested on:

 * Debian:   5     / 6   / 7
 * Redhat:   5.x   / 6.x
 * CentOS:   5.x   / 6.x
 * OpenSuSe: 12.x
 * SLES:     11.x

Should also work on (I'd appreciate reports on this distros and versions):

 * Ubuntu
 * Fedora
 * Scientific Linux 6

Requirements
------------

 * If nsswitch is enabled (nsswitch => true) you'll need
   [puppet-nsswitch](https://github.com/torian/puppet-nsswitch.git)
 * If pam is enabled (pam => true) you'll need
   [puppet-pam](https://github.com/torian/puppet-pam.git)
 * If enable_motd is enabled (enable_motd => true) you'll need
   [puppet-motd](https://github.com/torian/puppet-motd.git)

Testing
-------

Unit tests: `rake spec`
Integration tests: `kitchen test`

TODO
----

 * ldap::server::master and ldap::server::slave do not copy
   the schemas specified by *index_inc*. It just adds an include to slapd
 * Need support for extending ACLs

CopyLeft
---------

Copyleft (C) 2012 Emiliano Castagnari <ecastag@gmail.com> (a.k.a. Torian)

