desc "Delete all existing tags."
task :reset_tags => :environment do
  puts "Deleting all #{Tag.count} tags..."
  Tag.delete_all
  puts "Done!"
end
