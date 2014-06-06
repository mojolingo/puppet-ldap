require 'serverspec'

include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS

RSpec.configure do |c|
  c.before :all do
    c.path = '/sbin:/usr/sbin'
  end
end

describe "slapd master" do
  describe "server-wide concerns" do
    describe service('slapd') do
      it { should be_enabled }
      it { should be_running }
    end

    describe port(389) do
      it { should be_listening }
    end

    # Can bind as system root user
    describe command('ldapwhoami -H ldapi:/// -Y EXTERNAL') do
      it { should return_stdout /dn:gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth/ }
    end

    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=schema,cn=config" "(objectClass=olcSchemaConfig)" cn') do
      %w{inetorgperson cosine nis core ppolicy}.each do |schema|
        it { should return_stdout /#{schema}/ }
      end
    end

    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcModuleList)" olcModuleLoad') do
      %w{back_hdb ppolicy}.each do |mod|
        it { should return_stdout /#{mod}/ }
      end
    end

    # Syncprov
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcModuleList)" olcModuleLoad') do
      it { should return_stdout /syncprov/ }
    end

    # TLS
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(cn=config)"') do
      let(:cert_path) do
        case os[:family]
        when 'RedHat'
          '/etc/openldap/certs'
        when 'Debian', 'Ubuntu'
          '/etc/ssl/certs'
        end
      end
      it { should return_stdout %r{olcTLSCACertificateFile: #{cert_path}/ca\.pem} }
      it { should return_stdout %r{olcTLSCertificateFile: #{cert_path}/master-ldap\.pem} }
      it { should return_stdout %r{olcTLSCertificateKeyFile: #{cert_path}/master-ldap\.key} }
    end
    describe command('ldapwhoami -H ldaps:/// -x -D cn=admin,dc=foo,dc=bar -w password') do
      it { should return_stdout /dn:cn=admin,dc=foo,dc=bar/ }
    end

    # Setting arbitrary config options
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(cn=config)" olcConcurrency') do
      it { should return_stdout %r{olcConcurrency: 1} }
    end

    # Log level
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(cn=config)" olcLogLevel') do
      it { should return_stdout %r{olcLogLevel: 4} }
    end

    let(:run_dir) do
      case property[:os_by_host]['localhost'][:family]
      when /redhat/i
        '/var/run/openldap'
      else
        '/var/run/slapd'
      end
    end

    # PID file
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(cn=config)" olcPidFile') do
      it { should return_stdout %r{olcPidFile: #{run_dir}/slapd.pid} }
    end

    # Args file
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(cn=config)" olcArgsFile') do
      it { should return_stdout %r{olcArgsFile: #{run_dir}/slapd.args} }
    end

    # Bind Anon
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(cn=config)" olcDisallows') do
      its(:stdout) { should include 'olcDisallows: bind_anon' }
    end
  end

  describe 'primary database' do
    # Can bind as specified root user w/ password
    describe command('ldapwhoami -H ldapi:/// -x -D cn=admin,dc=foo,dc=bar -w password') do
      it { should return_stdout /dn:cn=admin,dc=foo,dc=bar/ }
    end

    # Can bind as a created user
    describe command('ldapwhoami -H ldapi:/// -x -D uid=testuser,ou=users,dc=foo,dc=bar -w somepassword') do
      it { should return_stdout /dn:uid=testuser,ou=users,dc=foo,dc=bar/ }
    end

    # Requested suffix exists in cn=config
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=foo,dc=bar)" olcSuffix') do
      it { should return_stdout /olcSuffix: dc=foo,dc=bar/ }
    end

    # Once created, the root org is readable by system root
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -s base -b "dc=foo,dc=bar"') do
      it { should return_stdout /o: Foo Dot Bar/ }
    end

    # Once created, the root org is readable by the DIT root user
    describe command('ldapsearch -H ldapi:/// -x -D cn=admin,dc=foo,dc=bar -w password -s base -b "dc=foo,dc=bar"') do
      it { should return_stdout /o: Foo Dot Bar/ }
    end

    # Directory can be manipulated by ldapdn resources
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -s base -b "ou=users,dc=foo,dc=bar" "(objectClass=organizationalUnit)"') do
      it { should return_stdout /ou: users/ }
    end

    # Last-modified overlay is on
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=foo,dc=bar)" olcLastMod') do
      it { should return_stdout /olcLastMod: TRUE/ }
    end

    # DB performance tweaks are set
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=foo,dc=bar)" olcDbCheckpoint') do
      it { should return_stdout /512 30/ }
    end

    # Indices (default and specified)
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=foo,dc=bar)" olcDbIndex') do
      [
        'olcDbIndex: objectClass \s*eq',
        'olcDbIndex: entryCSN \s*eq',
        'olcDbIndex: entryUUID \s*eq',
        'olcDbIndex: uidNumber \s*eq',
        'olcDbIndex: gidNumber \s*eq',
        'olcDbIndex: cn \s*pres,sub,eq',
        'olcDbIndex: sn \s*pres,sub,eq',
        'olcDbIndex: uid \s*pres,sub,eq',
        'olcDbIndex: displayName \s*pres,sub,eq',
        'olcDbIndex: title \s*pres',
      ].each do |index|
        it { should return_stdout /#{index}/ }
      end
    end

    # ACLs
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=foo,dc=bar)" olcAccess | perl -p00e \'s/\r?\n //g\'') do
      [
        /to \*  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" manage/,
        /to dn.subtree="dc=foo,dc=bar"  attrs=userPassword,shadowLastChange  by dn.base="cn=sync,dc=foo,dc=bar" read  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" write  by self write  by anonymous auth  by \* none/,
        /to dn.subtree="dc=foo,dc=bar"  attrs=objectClass,entry,gecos,homeDirectory,uid,uidNumber,gidNumber,cn,memberUid  by dn.base="cn=sync,dc=foo,dc=bar" read  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" write  by \* read/,
        /to dn.subtree="dc=foo,dc=bar"  by dn.base="cn=sync,dc=foo,dc=bar" read  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" write  by self read  by \* read/,
      ].each do |entry|
        it { should return_stdout entry }
      end
    end

    # Syncprov
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(objectClass=olcSyncProvConfig)" olcSpCheckpoint') do
      it { should return_stdout /100 10/ }
    end
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(objectClass=olcSyncProvConfig)" olcSpSessionlog') do
      it { should return_stdout /100/ }
    end
  end

  describe 'secondary database' do
    # Can bind as specified root user w/ password
    describe command('ldapwhoami -H ldapi:/// -x -D cn=admin,dc=doo,dc=dah -w otherpassword') do
      it { should return_stdout /dn:cn=admin,dc=doo,dc=dah/ }
    end

    # Can bind as a created user
    describe command('ldapwhoami -H ldapi:/// -x -D uid=testuser,ou=users,dc=doo,dc=dah -w somepassword') do
      it { should return_stdout /dn:uid=testuser,ou=users,dc=doo,dc=dah/ }
    end

    # Requested suffix exists in cn=config
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=doo,dc=dah)" olcSuffix') do
      it { should return_stdout /olcSuffix: dc=doo,dc=dah/ }
    end

    # Once created, the root org is readable by system root
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -s base -b "dc=doo,dc=dah"') do
      it { should return_stdout /o: Doo Dot Dah/ }
    end

    # Once created, the root org is readable by the DIT root user
    describe command('ldapsearch -H ldapi:/// -x -D cn=admin,dc=doo,dc=dah -w otherpassword -s base -b "dc=doo,dc=dah"') do
      it { should return_stdout /o: Doo Dot Dah/ }
    end

    # Directory can be manipulated by ldapdn resources
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -s base -b "ou=users,dc=doo,dc=dah" "(objectClass=organizationalUnit)"') do
      it { should return_stdout /ou: users/ }
    end

    # Last-modified overlay is on
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=doo,dc=dah)" olcLastMod') do
      it { should return_stdout /olcLastMod: TRUE/ }
    end

    # DB performance tweaks are set
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=doo,dc=dah)" olcDbCheckpoint') do
      it { should return_stdout /512 30/ }
    end

    # Indices (default and specified)
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=doo,dc=dah)" olcDbIndex') do
      [
        'olcDbIndex: objectClass \s*eq',
        'olcDbIndex: entryCSN \s*eq',
        'olcDbIndex: entryUUID \s*eq',
        'olcDbIndex: uidNumber \s*eq',
        'olcDbIndex: gidNumber \s*eq',
        'olcDbIndex: cn \s*pres,sub,eq',
        'olcDbIndex: sn \s*pres,sub,eq',
        'olcDbIndex: uid \s*pres,sub,eq',
        'olcDbIndex: displayName \s*pres,sub,eq',
        'olcDbIndex: title \s*pres',
      ].each do |index|
        it { should return_stdout /#{index}/ }
      end
    end

    # ACLs
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=doo,dc=dah)" olcAccess | perl -p00e \'s/\r?\n //g\'') do
      [
        /to \*  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" manage/,
        /to dn.subtree="dc=doo,dc=dah"  attrs=userPassword,shadowLastChange  by dn.base="cn=sync,dc=doo,dc=dah" read  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" write  by self write  by anonymous auth  by \* none/,
        /to dn.subtree="dc=doo,dc=dah"  attrs=objectClass,entry,gecos,homeDirectory,uid,uidNumber,gidNumber,cn,memberUid  by dn.base="cn=sync,dc=doo,dc=dah" read  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" write  by \* read/,
        /to dn.subtree="dc=doo,dc=dah"  by dn.base="cn=sync,dc=doo,dc=dah" read  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" write  by self read  by \* read/,
      ].each do |entry|
        it { should return_stdout entry }
      end
    end

    # Syncprov
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(objectClass=olcSyncProvConfig)" olcSpCheckpoint') do
      it { should return_stdout /100 10/ }
    end
    describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(objectClass=olcSyncProvConfig)" olcSpSessionlog') do
      it { should return_stdout /100/ }
    end
  end
end
