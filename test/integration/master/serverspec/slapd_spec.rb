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

  %w{inetorgperson cosine nis core ppolicy}.each do |schema|
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=schema,cn=config" "(objectClass=olcSchemaConfig)" cn') do
      it { should return_stdout /#{schema}/ }
    end
  end

  %w{back_bdb ppolicy}.each do |mod|
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcModuleList)" olcModuleLoad') do
      it { should return_stdout /#{mod}/ }
    end
  end

  # Last-modified overlay is on
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcLastMod') do
    it { should return_stdout /olcLastMod: TRUE/ }
  end

  # DB performance tweaks are set
  [
    'set_cachesize 0 2097152 0',
    'set_lk_max_objects 1500',
    'set_lk_max_locks 1500',
    'set_lk_max_lockers 1500',
  ].each do |tweak|
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcDbConfig') do
      it { should return_stdout /#{tweak}/ }
    end
  end
  describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcDatabaseConfig)" olcDbCheckpoint') do
    it { should return_stdout /512 30/ }
  end
end
