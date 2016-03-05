class Photo
  attr_accessor :id       #String form of the GridFS file _id
  attr_accessor :location #Point to hold the location
  attr_accessor :contents #raw data of the photo

  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize param={}
    @id = param[:_id].nil? ? param[:id] : param[:_id].to_s
    @location = Point.new(param [:metadata][:location]) if !param[:metadata].nil?
    #@contents
  end

end