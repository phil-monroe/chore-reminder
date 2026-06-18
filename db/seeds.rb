# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

today_wday = Date.current.wday

alex = User.find_or_create_by!(phone_number: "+15555550101") do |u|
  u.name = "Alex"
end

jamie = User.find_or_create_by!(phone_number: "+15555550102") do |u|
  u.name = "Jamie"
end

alex_feed_pets = TaskDefinition.find_or_create_by!(user: alex, name: "Feed the pets") do |td|
  td.description = "Fill both bowls with **1 cup** of dry food.\n\n- Dog bowl is by the back door\n- Cat bowl is on the counter"
  td.recurrence_days = (0..6).to_a
end

alex_trash = TaskDefinition.find_or_create_by!(user: alex, name: "Take out the trash") do |td|
  td.description = "Bins go to the curb the night before pickup."
  td.recurrence_days = [today_wday]
end

jamie_dishes = TaskDefinition.find_or_create_by!(user: jamie, name: "Load the dishwasher") do |td|
  td.description = "Rinse plates before loading. Run it once full."
  td.recurrence_days = [today_wday]
end

[alex_feed_pets, alex_trash, jamie_dishes].each(&:generate_task_for_today!)

Task.find_or_create_by!(user: alex, name: "Water the porch plants")
Task.find_or_create_by!(user: jamie, name: "Pack school lunch")

ReminderDefinition.find_or_create_by!(user: alex, time_of_day: "08:00")
ReminderDefinition.find_or_create_by!(user: jamie, time_of_day: "08:15")

# standard:disable Rails/Output
puts "Seeded #{User.count} users, #{TaskDefinition.count} task definitions, #{Task.count} tasks, #{ReminderDefinition.count} reminder definitions."
# standard:enable Rails/Output
