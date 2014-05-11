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
end
