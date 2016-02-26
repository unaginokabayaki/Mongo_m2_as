class Point
  attr_accessor :longitude, :latitude

  def initialize keys={}
    keys={} if keys.nil?
    if keys[:coordinates].nil?
      @latitude = keys[:lat]
      @longitude = keys[:lng]
    else
      co = keys[:coordinates]
      @latitude = co[1]
      @longitude = co[0]
    end
    return to_hash
  end

  def to_hash
    #{"lat": @latitude, "lng": @longtitude }
    {type: "Point", coordinates: [@longitude, @latitude]}
  end


end