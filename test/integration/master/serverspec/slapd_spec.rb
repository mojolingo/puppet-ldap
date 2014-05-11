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
end
