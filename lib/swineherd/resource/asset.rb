module Swineherd
  class Asset
    include Gorillib::Model
    include Swineherd::SimpleUnits
    include Swineherd::SimpleUnits::HasBytes

    field :name,        Symbol, position: 0, doc: 'unique handle for this asset'
    field :doc,         String,              doc: 'description of the asset'
  end

  class AssetCollection < Gorillib::ModelCollection
    self.item_type  = Asset
    self.key_method = :name
  end
end
