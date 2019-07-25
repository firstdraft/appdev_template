namespace(:dev) do
  desc "Hydrate the database with some dummy data to look at so that developing is easier"
  task({ :prime => :environment}) do
     # Create a top level spinner
     # spinners = TTY::Spinner::Multi.new("[:spinner] rails dev:prime")
     # Create nested spinners for each model
     # sp1 = spinners.register "[:spinner] Create Movies"
     # sp1.auto_spin
     # Movie.create([...])
     # sp1.success
  end
end
