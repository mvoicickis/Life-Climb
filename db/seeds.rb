demo = User.find_or_initialize_by(email_address: "demo@lifepoints.test")
demo.password = "password"
demo.password_confirmation = "password"
demo.save!

habits = [
  { name: "Morning run", description: "Run for at least 20 minutes", points: 10, frequency: "daily" },
  { name: "Read 30 minutes", description: "Read a book or article", points: 5, frequency: "daily" },
  { name: "Meditate", description: "10 minutes of quiet time", points: 5, frequency: "daily" }
]

habits.each do |attrs|
  demo.habits.find_or_create_by!(name: attrs[:name]) do |habit|
    habit.description = attrs[:description]
    habit.points = attrs[:points]
    habit.frequency = attrs[:frequency]
    habit.active = true
  end
end

puts "Seeded demo user: demo@lifepoints.test / password"
puts "Created #{demo.habits.count} habits"
