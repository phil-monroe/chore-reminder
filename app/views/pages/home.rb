class Views::Pages::Home < Views::Pages::Base
  def initialize(html:)
    @html = html
  end

  private

  def doc_html = @html
end
