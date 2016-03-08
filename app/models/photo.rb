class Photo
  attr_accessor :id       #String form of the GridFS file _id
  attr_accessor :location #Point to hold the location
  attr_accessor :contents #raw data of the photo

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.fs
    self.mongo_client.database.fs
  end

  def initialize param={}
    @id = param[:_id].nil? ? param[:id] : param[:_id].to_s
    @location = Point.new(param [:metadata][:location]) if !param[:metadata].nil?
    #@contents
  end

  def persisted?
    !@id.nil?
  end

  def save
    if persisted?
    else
      f=@contents

      # 情報取得
      f.rewind
      gps=EXIFR::JPEG.new(f).gps 
      @location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
      
      # メタデータ
      description={}
      description[:content_type]="image/jpeg"
      description[:metadata]={}
      description[:metadata][:location]=@location.to_hash
      #description[:filename]="test.jpg"

      # 保存
      f.rewind
      grid_file=Mongo::Grid::File.new(f.read, description)
      _id=self.class.mongo_client.database.fs.insert_one(grid_file)
      @id=_id.to_s
    end 
  end

  def self.all(offset=0, limit=:unlimited)
    
    view=self.mongo_client.database.fs.find
    view=view.skip(offset)
    view=view.limit(limit) if limit!=:unlimited

    photos=[]
    photos=view.to_a.map {|doc| Photo.new(doc)}
    return photos
  end

  def self.find id
    view=self.mongo_client.database.fs.find(_id:BSON::ObjectId.from_string(id)).first
    Photo.new(view) if !view.nil?
  end

  def contents
    if @contents.nil?
      return nil
    else
      @contents.rewind
      @contents.read
    end
      
  end

  def destroy
    grid_file=self.class.fs.find_one(_id:BSON::ObjectId.from_string(@id))
    self.class.fs.delete_one(grid_file)
  end
end