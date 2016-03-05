
class Place
  # include ActiveModel::Model
  attr_accessor :id, :formatted_address, :location, :address_components

  def self.mongo_client
    Mongoid::Clients.default
  end
  def self.collection
    self.mongo_client[:places]
  end
  def self.load_all file
    # json to hash to array
    data=JSON.parse(file.read) if file.kind_of?(File)

    # insert array to the collection
    self.collection.insert_many(data) if !data.nil?
  end

  def initialize keys={}
    keys = {} if keys.nil?
    #@coll = self.class.collection

    #hashがRailsのPlaceクラスから来た場合:mongodbから来た場合
    @id = keys[:_id].nil? ? keys[:id] : keys[:_id].to_s

    @address_components = []
    acs = keys[:address_components] ||= []
    acs.each do |ac|
      @address_components << AddressComponent.new(ac)
    end

    @formatted_address = keys[:formatted_address]

    geoloc = keys[:geometry].nil? ? nil : keys[:geometry][:geolocation]
    @location = Point.new(geoloc)
    #@location = geoloc.nil? ? nil : Point.new(geoloc) 
  end

  def self.find_by_short_name short_name
    self.collection.find(:"address_components.short_name"=>short_name)
  end

  # viewsを1行ずつ取り出してPlaceに変換。Placeの配列にして戻す。
  def self.to_places views
    places = []
    views.each do |v|
      p = Place.new(v)
      places << p
    end
    return places
  end

  def self.find id
    doc = self.collection.find(_id:BSON::ObjectId.from_string(id)).first
    return doc.nil? ? nil : Place.new(doc)
  end

  def self.all(offset=0, limit=nil)
    docs = self.collection.find.skip(offset)
    docs = docs.limit(limit) if !limit.nil?

    #ブロックの結果を配列にする
    places = [] 
    places = docs.to_a.map do |doc|
      Place.new(doc)
    end
    #上と同じ
    #places = []
    # docs.to_a.each do |doc|
    #   p = Place.new(doc)
    #   places << p
    # end
    return places
  end
  
  def destroy
    #@coll.find(_id:BSON::ObjectId.from_string(@id)).delete_one
    self.class.collection.find(_id:BSON::ObjectId.from_string(@id)).delete_one
  end

  def self.get_address_components(sort={}, offset=0, limit=nil)
    pipeline = []
    pipeline << {:$unwind=>"$address_components"}
    pipeline << {:$project=>{:address_components=>1,:formatted_address=>1,:"geometry.geolocation"=>1}}
    pipeline << {:$sort=>sort} if sort!={}
    pipeline << {:$skip=>offset}
    pipeline << {:$limit=>limit} if !limit.nil?
    self.collection.find.aggregate(pipeline)
  end
  def self.get_country_names
    view=self.get_address_components.view
    
    pipeline = []
    pipeline << {:$unwind=>"$address_components"}
    pipeline << {:$project=>{:"address_components.long_name"=>1,:"address_components.types"=>1}}
    pipeline << {:$match=>{:"address_components.types"=>"country"}}
    pipeline << {:$group=>{:_id=>"$address_components.long_name"}}
    view=view.aggregate(pipeline)
    view.to_a.map { |h| h[:_id] }
  end
  def self.find_ids_by_country_code country_code
    view=self.get_address_components.view
    
    pipeline = []
    pipeline << {:$match=>{:$and=>[{:"address_components.types"=>"country"},{:"address_components.short_name"=>country_code}]}}
    pipeline << {:$project=>{:_id=>1}}
    view=view.collection.find.aggregate(pipeline)
    view.to_a.map { |h| h[:_id].to_s }
  end
  
  def self.create_indexes
    self.collection.indexes.create_one({:"geometry.geolocation"=>Mongo::Index::GEO2DSPHERE})
  end
  def self.remove_indexes
    #indexes = self.collection.indexes.map {|r| r[:name] }
    self.collection.indexes.drop_one("geometry.geolocation_2dsphere")
  end
  def self.near(point, max_meters=:unlimited)
    geo_query={}
    geo_query[:$geometry]=point.to_hash
    geo_query[:$maxDistance]=max_meters if max_meters!=:unlimited
    self.collection.find(:"geometry.geolocation"=>{:$near=>geo_query})
    #Pointで返す
    #view.to_a.each {|pt| Point.new(pt)}
  end
  def near(max_meters=:unlimited)
    view=self.class.near(@location, max_meters)
    self.class.to_places(view)
  end

end
