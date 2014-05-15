Puppet::Type.newtype :ldapdn do
  ensurable do
    newvalue :present do
      provider.create
    end

    newvalue :absent do
      provider.destroy
    end

    defaultto :present
  end

  autorequire(:service) do
    %w{ldap slapd}
  end

  @doc = "This type provides the capability to manage LDAP DN entries."

  newparam :name do
    desc "The canonical name of the rule."

    isnamevar

    newvalues(/^.*$/)
  end

  newparam :attributes, :array_matching => :all do
    desc "Specify the attribute you want to ldapmodify"
  end

  newparam :unique_attributes, :array_matching => :all do
    desc "Specify the attribute that are unique in the dn"
  end

  newparam :indifferent_attributes, :array_matching => :all do
    desc "Specify the attributes you dont care about their subsequent values (e.g. passwords)"
  end

  newparam :dn do
    desc "Specify the value of the attribute you want to ldapmodify"
  end

  newparam :auth_opts do
    desc "Specify the options passed to ldapadd/ldapmodify for authentication. Defaults to -QY EXTERNAL."
  end
end
