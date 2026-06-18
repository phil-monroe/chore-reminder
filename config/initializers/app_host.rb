# APP_HOST (see AppHost, app/services/app_host.rb) controls which Host
# headers Action Dispatch's DNS-rebinding protection will accept, in both
# development and production — every comma-separated host is allowed, not
# just the first (which is the one AppHost.primary uses for SMS links, see
# app/jobs/send_reminder_job.rb). Optional: production has no host
# restriction by default, and development already permits localhost
# regardless, so leaving APP_HOST unset preserves Rails' defaults.
#
# require_relative rather than relying on Zeitwerk autoloading: the main
# autoloader isn't set up yet when config/initializers run (it happens later,
# in the finisher), so a bare constant reference here would raise.
require_relative "../../app/services/app_host"

hosts = AppHost.all
if hosts.any?
  Rails.application.config.hosts.concat(hosts.map { |host| host.split(":").first })
  Rails.application.config.host_authorization = {exclude: ->(request) { request.path == "/up" }}
end
