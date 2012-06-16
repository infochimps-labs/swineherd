module Swineherd

  class ResourceActionError < StandardError
    # Used as the message
    class_attribute :doc
    self.doc = "Tried something unpossible"

    # @param doc_str [String] the message to include in the error trace
    def initialize(doc_str=nil)
      super()
      self.doc = doc_str if doc_str.present?
    end

    # @returns the error message to raise
    def to_s
      doc
    end
  end

  class ResourceExistsError < ResourceActionError
    self.doc = "Resource already exists"
  end
  class ResourceAbsentError < ResourceActionError
    self.doc = "Resource is absent"
  end

end
