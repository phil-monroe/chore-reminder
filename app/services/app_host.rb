# Parses the comma-separated APP_HOST env var (see config/initializers/app_host.rb
# and app/jobs/send_reminder_job.rb). Multiple hosts can all be accepted by the
# server (e.g. a LAN hostname and a public domain pointing at the same app),
# but message links always use the first one.
module AppHost
  DEFAULT = "localhost:3000"

  def self.all
    ENV["APP_HOST"].to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def self.primary
    all.first || DEFAULT
  end
end
