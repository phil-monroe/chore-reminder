# frozen_string_literal: true

class Components::Base < Phlex::HTML
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

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
