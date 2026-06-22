# Compares the user's current next-up task against whatever it was before
# some list modification (passed in as an id, not a Task, since the caller
# captured it before the modification and the record it pointed to may since
# have been deleted/completed/moved) and only texts the user when that's
# actually different — so e.g. renaming a task elsewhere in the list, or
# moving the bottom task around, doesn't trigger a notification.
class User::NotifyIfNextTaskChanged
  NO_TASKS_BODY = "No more tasks!".freeze

  def initialize(user:, previous_next_task_id:, sender: nil)
    @user = user
    @previous_next_task_id = previous_next_task_id
    @sender = sender
  end

  def call
    return if @user.snoozed?

    current_next_task = Task.next_for(@user)
    return if current_next_task&.id == @previous_next_task_id

    body = current_next_task ? current_next_task.reminder_body(@user.message_template) : NO_TASKS_BODY
    User::SendMessage.new(user: @user, body: body, sender: @sender).call
  end
end
