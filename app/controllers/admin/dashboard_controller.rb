class DashboardController < ApplicationController
  def index
    @users = User.all.includes(:tasks)
    render Views::Dashboard::Index.new(users: @users)
  end
end
