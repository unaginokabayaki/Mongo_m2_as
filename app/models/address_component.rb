  class AddressComponent
    attr_reader :long_name, :short_name, :types

    def initialize keys={}
      keys={} if keys.nil?
      @long_name = keys[:long_name]
      @short_name = keys[:short_name]
      @types = keys[:types]
    end
  end

