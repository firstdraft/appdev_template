namespace(:dev) do
  desc "Hydrate the database with dummy data to look at so developing is easier"
  task({ :prime => :environment}) do
  end
end
