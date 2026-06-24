require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "/ renders the features overview with no Basic Auth credentials" do
    get root_path, headers: {"Authorization" => ""}

    assert_response :success
    assert_match "Per-person chore lists", response.body
  end

  test "/help renders the how-to guide with no Basic Auth credentials" do
    get help_path, headers: {"Authorization" => ""}

    assert_response :success
    assert_match "Add a household member", response.body
  end
end
