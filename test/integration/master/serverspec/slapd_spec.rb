require 'serverspec'

include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS

RSpec.configure do |c|
  c.before :all do
    c.path = '/sbin:/usr/sbin'
  end
end

describe "slapd" do
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

  # Can bind as specified root user w/ password
  describe command('ldapwhoami -H ldapi:/// -x -D cn=admin,dc=foo,dc=bar -w password') do
    it { should return_stdout /dn:cn=admin,dc=foo,dc=bar/ }
  end

  # Requested suffix exists in cn=config
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcSuffix') do
    it { should return_stdout /olcSuffix: dc=foo,dc=bar/ }
  end

  # The root organisation can be created
  describe command("echo \"dn: dc=foo,dc=bar\nobjectClass: dcObject\nobjectClass: organization\ndc: foo\no: Foo Dot Bar\" | ldapadd -H ldapi:/// -Y EXTERNAL") do
    it { should return_stdout /adding new entry/ }
  end

  # Once created, the root org is readable by system root
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -s base -b "dc=foo,dc=bar"') do
    it { should return_stdout /o: Foo Dot Bar/ }
  end

  # Once created, the root org is readable by the DIT root user
  describe command('ldapsearch -H ldapi:/// -x -D cn=admin,dc=foo,dc=bar -w password -s base -b "dc=foo,dc=bar"') do
    it { should return_stdout /o: Foo Dot Bar/ }
  end

  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=schema,cn=config" "(objectClass=olcSchemaConfig)" cn') do
    %w{inetorgperson cosine nis core ppolicy}.each do |schema|
      it { should return_stdout /#{schema}/ }
    end
  end

  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcModuleList)" olcModuleLoad') do
    %w{back_bdb ppolicy}.each do |mod|
      it { should return_stdout /#{mod}/ }
    end
  end

  # Last-modified overlay is on
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcLastMod') do
    it { should return_stdout /olcLastMod: TRUE/ }
  end

  # DB performance tweaks are set
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcDbConfig') do
    [
      'set_cachesize 0 2097152 0',
      'set_lk_max_objects 1500',
      'set_lk_max_locks 1500',
      'set_lk_max_lockers 1500',
    ].each do |tweak|
      it { should return_stdout /#{tweak}/ }
    end
  end
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcDbCheckpoint') do
    it { should return_stdout /512 30/ }
  end

  # Indices (default and specified)
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcDbIndex') do
    [
      'olcDbIndex: objectClass eq',
      'olcDbIndex: entryCSN eq',
      'olcDbIndex: entryUUID eq',
      'olcDbIndex: uidNumber eq',
      'olcDbIndex: gidNumber eq',
      'olcDbIndex: cn pres,eq,sub',
      'olcDbIndex: sn pres,eq,sub',
      'olcDbIndex: uid pres,eq,sub',
      'olcDbIndex: displayName pres,eq,sub',
      'olcDbIndex: mail pres',
    ].each do |index|
      it { should return_stdout /#{index}/ }
    end
  end

  # ACLs
  describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(olcSuffix=dc=foo,dc=bar)" olcAccess | perl -p00e \'s/\r?\n //g\'') do
    [
      /to \*  by dn.base="gidNumber=0\+uidNumber=0,cn=peercred,cn=external,cn=auth" manage/,
      /to dn.subtree="dc=foo,dc=bar"  attrs=userPassword,shadowLastChange  by dn.base="cn=sync,dc=foo,dc=bar" read  by self write  by anonymous auth  by \* none/,
      /to dn.subtree="dc=foo,dc=bar"  attrs=objectClass,entry,gecos,homeDirectory,uid,uidNumber,gidNumber,cn,memberUid  by dn.base="cn=sync,dc=foo,dc=bar" read  by \* read/,
      /to dn.subtree="dc=foo,dc=bar"  by dn.base="cn=sync,dc=foo,dc=bar" read  by self read  by \* read/,
    ].each do |entry|
      it { should return_stdout entry }
    end
  end

  # Syncprov
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcModuleList)" olcModuleLoad') do
    it { should return_stdout /syncprov/ }
  end

  describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(objectClass=olcSyncProvConfig)" olcSpCheckpoint') do
    it { should return_stdout /100 10/ }
  end

  describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(objectClass=olcSyncProvConfig)" olcSpSessionlog') do
    it { should return_stdout /100/ }
  end

  # TLS
  describe command('ldapsearch -H ldapi:/// -LLL -Y EXTERNAL -b "cn=config" "(cn=config)"') do
    it { should return_stdout %r{olcTLSCACertificateFile: /etc/ssl/certs/ca\.pem} }
    it { should return_stdout %r{olcTLSCertificateFile: /etc/ssl/certs/master-ldap\.pem} }
    it { should return_stdout %r{olcTLSCertificateKeyFile: /etc/ssl/certs/master-ldap\.key} }
  end
end
