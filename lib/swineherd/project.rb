module Swineherd
  class Project
    include Gorillib::Builder

    field :name,     Symbol, position: 0, doc: 'name of this project'
    field :category, Symbol, position: 1, doc: 'category to organize this project under'

    def directory(*args, &block)
      Swineherd::DirectoryResource.new(*args, &block)
    end

    def project_path(*args)
      Swineherd::FileResource.path_to(:rawd_dir, category.to_s, name.to_s, *args)
    end

  end
end
