module ActiveRecord
  class Relation
    def to_s
      "Array containing #{count} #{model} #{"record".pluralize(count)}"
    end
  end
end
