class Admin::DashboardController < Admin::BaseController
  def index
    @users = User.all.includes(:tasks)
    render Views::Admin::Dashboard::Index.new(users: @users)
  end
end
