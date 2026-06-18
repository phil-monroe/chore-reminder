class User::SendWelcomeMessage
  def initialize(user:, sender: nil)
    @user = user
    @sender = sender
  end

  def call
    User::SendMessage.new(user: @user, body: welcome_body, sender: @sender).call
  end

  private

  def welcome_body
    "Hi #{@user.name}! You're set up on Chore Reminder. You'll get a text here whenever it's time for your next chore."
  end
end
