class Admin::DashboardController < ApplicationController
  def index
    @users = User.all.includes(:tasks)
    render Views::Admin::Dashboard::Index.new(users: @users)
  end
end
