class User::SendMessage
  class BlankBodyError < StandardError; end

  def initialize(user:, body:, sender: nil)
    @user = user
    @body = body.to_s.strip
    @sender = sender
  end

  def call
    raise BlankBodyError, "Message can't be blank." if @body.blank?

    # Constructed lazily, not as a default argument: Sms::TwilioSender.new
    # reads Twilio credentials from ENV eagerly, so building it before the
    # blank check above would raise on missing credentials before a blank
    # body ever gets a chance to be rejected.
    (@sender || Sms::TwilioSender.new).send(to: @user.phone_number, body: @body)
  end
end
