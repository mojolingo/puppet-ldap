require 'puppet/provider'
require 'tempfile'

module PuppetLDAP
  # This is shamelessly stolen from ActiveSuport 3.2 until Puppet moves to Ruby 1.9. It is required to prevent declared attributes being reordered (eg objectClass being moved from first position).

  class OrderedHash < ::Hash
    # Returns true to make sure that this hash is extractable via <tt>Array#extract_options!</tt>
    def extractable_options?
      true
    end

    # Hash is ordered in Ruby 1.9!
    if RUBY_VERSION < '1.9'

      # In MRI the Hash class is core and written in C. In particular, methods are
      # programmed with explicit C function calls and polymorphism is not honored.
      #
      # For example, []= is crucial in this implementation to maintain the @keys
      # array but hash.c invokes rb_hash_aset() originally. This prevents method
      # reuse through inheritance and forces us to reimplement stuff.
      #
      # For instance, we cannot use the inherited #merge! because albeit the algorithm
      # itself would work, our []= is not being called at all by the C code.

      def initialize(*args, &block)
        super
        @keys = []
      end

      def self.[](*args)
        ordered_hash = new

        if (args.length == 1 && args.first.is_a?(Array))
          args.first.each do |key_value_pair|
            next unless (key_value_pair.is_a?(Array))
            ordered_hash[key_value_pair[0]] = key_value_pair[1]
          end

          return ordered_hash
        end

        unless (args.size % 2 == 0)
          raise ArgumentError.new("odd number of arguments for Hash")
        end

        args.each_with_index do |val, ind|
          next if (ind % 2 != 0)
          ordered_hash[val] = args[ind + 1]
        end

        ordered_hash
      end

      def initialize_copy(other)
        super
        # make a deep copy of keys
        @keys = other.keys
      end

      def []=(key, value)
        @keys << key unless has_key?(key)
        super
      end

      def delete(key)
        if has_key? key
          index = @keys.index(key)
          @keys.delete_at index
        end
        super
      end

      def delete_if
        super
        sync_keys!
        self
      end

      def reject!
        super
        sync_keys!
        self
      end

      def reject(&block)
        dup.reject!(&block)
      end

      def keys
        @keys.dup
      end

      def values
        @keys.collect { |key| self[key] }
      end

      def to_hash
        self
      end

      def to_a
        @keys.map { |key| [ key, self[key] ] }
      end

      def each_key
        return to_enum(:each_key) unless block_given?
        @keys.each { |key| yield key }
        self
      end

      def each_value
        return to_enum(:each_value) unless block_given?
        @keys.each { |key| yield self[key]}
        self
      end

      def each
        return to_enum(:each) unless block_given?
        @keys.each {|key| yield [key, self[key]]}
        self
      end

      def each_pair
        return to_enum(:each_pair) unless block_given?
        @keys.each {|key| yield key, self[key]}
        self
      end

      alias_method :select, :find_all

      def clear
        super
        @keys.clear
        self
      end

      def shift
        k = @keys.first
        v = delete(k)
        [k, v]
      end

      def merge!(other_hash)
        if block_given?
          other_hash.each { |k, v| self[k] = key?(k) ? yield(k, self[k], v) : v }
        else
          other_hash.each { |k, v| self[k] = v }
        end
        self
      end

      alias_method :update, :merge!

      def merge(other_hash, &block)
        dup.merge!(other_hash, &block)
      end

      # When replacing with another hash, the initial order of our keys must come from the other hash -ordered or not.
      def replace(other)
        super
        @keys = other.keys
        self
      end

      def invert
        OrderedHash[self.to_a.map!{|key_value_pair| key_value_pair.reverse}]
      end

      def inspect
        "#<OrderedHash #{super}>"
      end

      private
        def sync_keys!
          @keys.delete_if {|k| !has_key?(k)}
        end
    end
  end
end

Puppet::Type.type(:ldapdn).provide :ldapdn do
  desc ""

  commands :ldapmodifycmd => "/usr/bin/ldapmodify"
  commands :ldapaddcmd => "/usr/bin/ldapadd"
  commands :ldapsearchcmd => "/usr/bin/ldapsearch"

  def create
    ldap_apply_work
  end

  def destroy
    ldap_apply_work
  end

  def exists?
    @work_to_do = ldap_work_to_do(parse_attributes)

    # This is a bit of a butchery of an exists? method which is designed to return yes or no,
    # Whereas we are editing a multi-faceted record, and it might be in a semi-desired state.
    # However, as I want to still use the ensure param, I will have to live within its rules
    case resource[:ensure]
    when :present
      @work_to_do.empty?
    when :absent
      !@work_to_do.empty?
    end
  end

  def parse_attributes
    ldap_attributes = PuppetLDAP::OrderedHash.new
    Array(resource[:attributes]).each do |asserted_attribute|
      key,value = asserted_attribute.split(':', 2)
      ldap_attributes[key] = [] if ldap_attributes[key].nil?
      ldap_attributes[key] << value.strip!
    end
    ldap_attributes
  end

  def ldap_apply_work
    @work_to_do.each do |modify_type, modifications|
      modify_record = []
      modify_record << "dn: #{resource[:dn]}"

      modify_record << "changetype: modify" if modify_type == :ldapmodify

      modifications.each do |attribute, instructions|
        add_type = "add"
        instructions.each do |instruction|
          case instruction.first
          when :add
            if add_type == "add" and modify_type == :ldapmodify
              modify_record << "add: #{attribute}"
            else
              add_type = "add"
            end
            modify_record << "#{attribute}: #{instruction.last}"
            modify_record << "-" if modify_type == :ldapmodify
          when :delete
            modify_record << "delete: #{attribute}"
            modify_record << "-"
          when :replace
            modify_record << "replace: #{attribute}" if add_type == "add"
            add_type = "replace"
          end
        end
      end

      ldif = Tempfile.open("ldap_apply_work")
      ldif_file = ldif.path
      ldif.write modify_record.join("\n")
      ldif.close

      cmd = case modify_type
      when :ldapmodify
        :ldapmodifycmd
      when :ldapadd
        :ldapaddcmd
      end

      begin
        command = [command(cmd), "-H", "ldapi:///", "-d", "0", "-f", ldif_file]
        command += resource[:auth_opts] || ["-QY", "EXTERNAL"]
        Puppet.debug("\n\n" + File.open(ldif_file, 'r') { |file| file.read })
        output = execute(command)
        Puppet.debug(output)
      rescue Puppet::ExecutionFailure => ex
        raise Puppet::Error, "Ldap Modify Error:\n\n#{modify_record.join("\n")}\n\nError details:\n#{ex.message}"
      end
    end
  end

  def ldap_work_to_do(asserted_attributes)
    command = [command(:ldapsearchcmd), "-H", "ldapi:///", "-b", resource[:dn], "-s", "base", "-LLL", "-d", "0"]
    command += resource[:auth_opts] || ["-QY", "EXTERNAL"]
    begin
      ldapsearch_output = execute(command)
      Puppet.debug("ldapdn >>\n#{asserted_attributes.inspect}")
      Puppet.debug("ldapsearch >>\n#{ldapsearch_output}")
    rescue Puppet::ExecutionFailure => ex
      if ex.message.scan '/No such object (32)/'
        Puppet.debug("Could not find object: #{resource[:dn]}")
        return {} if resource[:ensure] == :absent
        work_to_do = PuppetLDAP::OrderedHash.new
        asserted_attributes.each do |asserted_key, asserted_values|
          key_work_to_do = []
          asserted_values.each do |asserted_value|
            key_work_to_do << [ :add, asserted_value ]
          end
          work_to_do[asserted_key] = key_work_to_do
        end
        Puppet.debug("WorkToDo: { :ldapadd => #{work_to_do}}")
        return { :ldapadd => work_to_do }
      else
        raise ex
      end
    end

    unique_attributes = resource[:unique_attributes]
    unique_attributes = [] if unique_attributes.nil?

    indifferent_attributes = resource[:indifferent_attributes]
    indifferent_attributes = [] if indifferent_attributes.nil?

    work_to_do = PuppetLDAP::OrderedHash.new
    found_attributes = {}
    found_keys = []

    asserted_attributes.each do |asserted_key, asserted_value|
      work_to_do[asserted_key] = []
      found_attributes[asserted_key] = []
    end

    ldapsearch_output.split(/\r?\n(?!\s)/).each do |line|
      line.gsub!(/[\r\n] /, '')
      line.gsub!(/\r?\n?$/, '')
      current_key,current_value = line.split(/:+ /, 2)
      found_keys << current_key
      if asserted_attributes.key?(current_key)
        Puppet.debug("search() #{current_key}: #{current_value}")
        same_as_an_asserted_value = false
        asserted_attributes[current_key].each do |asserted_value|
          Puppet.debug("check() #{current_key}: #{current_value}  <===>  #{current_key}: #{asserted_value}")
          same_as_an_asserted_value = true if asserted_value == current_value
          same_as_an_asserted_value = true if asserted_value.clone.gsub(/^\{.*?\}/, "") == current_value.clone.gsub(/^\{.*?\}/, "")
        end
        if same_as_an_asserted_value
          Puppet.debug("asserted and found: #{current_key}: #{current_value}")
          work_to_do[current_key] << [ :delete ] if resource[:ensure] == :absent
          found_attributes[current_key] << current_value.clone.gsub(/^\{.*?\}/, "")
        else
          Puppet.debug("not asserted: #{current_key}: #{current_value}")
          work_to_do[current_key] << [ :replace ] if resource[:ensure] == :present \
                                                 and unique_attributes.include?(current_key) \
                                                 and !indifferent_attributes.include?(current_key)
        end
      end
    end

    asserted_attributes.each do |asserted_key, asserted_values|
      asserted_values.each do |asserted_value|
        Puppet.debug("assert() #{asserted_key}: #{asserted_value}")

        if resource[:ensure] == :present
          work_to_do[asserted_key] << [ :add, asserted_value ] unless found_attributes[ asserted_key ].include?(asserted_value.clone.gsub(/^\{.*?\}/, "")) \
                                                                   or (found_keys.include?(asserted_key) and indifferent_attributes.include?(asserted_key))
        end
      end
    end

    work_to_do.delete_if { |key, operations| operations.empty? }

    if work_to_do.empty?
      Puppet.debug("conclusion: nothing to do")
      {}
    else
      Puppet.debug("conclusion: work to do: #{work_to_do.inspect}")
      { :ldapmodify => work_to_do }
    end
  end
end
