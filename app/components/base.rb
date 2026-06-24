# frozen_string_literal: true

class Components::Base < Phlex::HTML
  extend Phlex::Rails::HelperMacros

  # Include any helpers you want to be available across all components
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::Flash
  include Phlex::Rails::Helpers::CSRFMetaTags
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags
  include Phlex::Rails::Helpers::TurboIncludeTags
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::CollectionSelect
  include Phlex::Rails::Helpers::CollectionCheckboxes
  include Phlex::Rails::Helpers::URLFor
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::TimeFieldTag

  # Backs Views::Layouts::Nav's auth-dependent rendering (see
  # ApplicationController#admin_authenticated?).
  register_value_helper def admin_authenticated?(...) = nil

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
