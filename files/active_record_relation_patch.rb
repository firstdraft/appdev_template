module ActiveRecord
  class Relation
    def to_s
      "ActiveRecord Array of #{count} #{model}"
    end
  end
end
