class Views::Pages::Help < Views::Pages::Base
  def initialize(html:)
    @html = html
  end

  private

  def doc_html = @html
end
