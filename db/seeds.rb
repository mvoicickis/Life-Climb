demo = User.find_or_initialize_by(email_address: "demo@lifepoints.test")
demo.password = "password"
demo.password_confirmation = "password"
demo.home_stat_count = 6
demo.save!

demo.habits.where(name: [ "Morning run", "Read 30 minutes", "Meditate" ]).update_all(active: false, show_on_home: false)

trackers = [
  { name: "Move", unit: "steps", description: "Walk every day", points: 5, stat_type: "standard", min_value: 8000, max_value: nil, goal: nil },
  { name: "Sleep", unit: "hours", description: "Rest well", points: 5, stat_type: "standard", min_value: 7, max_value: 9, goal: nil },
  { name: "Water", unit: "glasses", description: "Drink water", points: 5, stat_type: "growth", goal: 8, min_value: nil, max_value: nil },
  { name: "Learn", unit: "pages", description: "Read pages", points: 5, stat_type: "growth", goal: 20, min_value: nil, max_value: nil },
  { name: "Income", unit: "money", description: "Money in today", points: 5, stat_type: "growth", goal: 50, min_value: nil, max_value: nil }
]

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
  [ "Move", 8000 ],
  [ "Sleep", 7 ],
  [ "Water", 6 ],
  [ "Learn", 10 ],
  [ "Income", 50 ]
].each do |name, amount|
  habit = demo.habits.find_by!(name: name)
  log = demo.daily_logs.find_or_initialize_by(habit: habit, logged_on: Date.yesterday)
  log.amount = amount
  log.goal = amount
  log.save!
end

puts "Seeded demo user: demo@lifepoints.test / password"
puts "On Home: #{demo.habits.active.on_home.ordered.pluck(:name).join(', ')}"
