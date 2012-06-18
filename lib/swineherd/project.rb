module Swineherd
  class Project
    include Gorillib::Builder

    field :name,     Symbol, :doc => 'name of this project'
    field :category, Symbol, :doc => 'category to organize this project under'

    def self.make(cat, name, attrs={}, &block)
      receive(attrs.merge(:category => cat, :name => name), &block)
    end

    def directory(*args, &block)
      Swineherd::DirectoryResource.new(*args, &block)
    end

    def project_path(*args)
      Swineherd::FileResource.path_to(:rawd_dir, category.to_s, name.to_s, *args)
    end


  end
end
