if ENV["ACTIVE_STORAGE_SERVICE"].present?
  Rails.application.config.active_storage.service = ENV["ACTIVE_STORAGE_SERVICE"].to_sym
end
