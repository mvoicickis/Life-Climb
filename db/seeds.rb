demo = User.find_or_initialize_by(email_address: "demo@lifepoints.test")
demo.password = "password"
demo.password_confirmation = "password"
demo.home_stat_count = 6
demo.save!

demo.habits.where(name: [ "Morning run", "Read 30 minutes", "Meditate" ]).update_all(active: false, show_on_home: false)

trackers = [
  { name: "Push-ups", unit: "reps", description: "Get stronger", points: 5, stat_type: "growth", goal: 30, min_value: nil, max_value: nil },
  { name: "Pages Read", unit: "pages", description: "Keep learning", points: 5, stat_type: "growth", goal: 20, min_value: nil, max_value: nil },
  { name: "Steps", unit: "steps", description: "Move every day", points: 5, stat_type: "growth", goal: nil, min_value: nil, max_value: nil },
  { name: "Sleep", unit: "hours", description: "Rest well", points: 5, stat_type: "standard", goal: nil, min_value: 8, max_value: 9 },
  { name: "Water", unit: "litres", description: "Stay hydrated", points: 5, stat_type: "standard", goal: nil, min_value: 2, max_value: 3 }
]

# Hide older demo habits not in the new set
demo.habits.where.not(name: trackers.map { |t| t[:name] }).update_all(active: false, show_on_home: false)

trackers.each_with_index do |attrs, index|
  habit = demo.habits.find_or_initialize_by(name: attrs[:name])
  habit.unit = attrs[:unit]
  habit.description = attrs[:description]
  habit.points = attrs[:points]
  habit.frequency = "daily"
  habit.active = true
  habit.show_on_home = true
  habit.position = index + 1
  habit.stat_type = attrs[:stat_type]
  habit.goal = attrs[:goal]
  habit.min_value = attrs[:min_value]
  habit.max_value = attrs[:max_value]
  habit.save!
end

[
  [ "Push-ups", 20 ],
  [ "Pages Read", 15 ],
  [ "Steps", 7500 ],
  [ "Sleep", 8 ],
  [ "Water", 2.5 ]
].each do |name, amount|
  habit = demo.habits.find_by!(name: name)
  log = demo.daily_logs.find_or_initialize_by(habit: habit, logged_on: Date.yesterday)
  log.amount = amount
  log.goal = habit.goal
  log.save!
end

puts "Seeded demo user: demo@lifepoints.test / password"
puts "On Home: #{demo.habits.active.on_home.ordered.pluck(:name).join(', ')}"
