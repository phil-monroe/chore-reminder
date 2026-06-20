module ControllerWithUser
  extend ActiveSupport::Concern

  included do
    before_action :set_user
    around_action :with_time_zone
  end

  private

  def set_user
    @user = User.find_by_param!(params[:user_id])
  end

  def with_time_zone(&block)
    Time.use_zone(@user.time_zone, &block)
  end
end
