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

  %w{inetorgperson cosine nis core}.each do |schema|
    describe command('ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=schema,cn=config" "(objectClass=olcSchemaConfig)" cn') do
      it { should return_stdout /#{schema}/ }
    end
  end
end
