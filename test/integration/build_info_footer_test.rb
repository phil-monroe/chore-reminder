require "test_helper"

class BuildInfoFooterTest < ActionDispatch::IntegrationTest
  test "shows the short sha, ref, and full message as a tooltip when GIT_SHA is set" do
    with_env(GIT_SHA: "abc1234def5678", GIT_REF: "main", GIT_COMMIT_MESSAGE: "Add build info footer") do
      get root_path
    end

    assert_select "span.text-gray-300[title='Add build info footer']", text: "abc1234 @ main"
  end

  test "omits the footer entirely when GIT_SHA is not set" do
    with_env(GIT_SHA: nil) do
      get root_path
    end

    assert_select "span.text-gray-300", count: 0
  end

  test "still renders without a ref or message when only GIT_SHA is set" do
    with_env(GIT_SHA: "abc1234def5678", GIT_REF: nil, GIT_COMMIT_MESSAGE: nil) do
      get root_path
    end

    assert_select "span.text-gray-300", text: "abc1234"
  end

  private

  def with_env(vars)
    original = vars.keys.index_with { |key| ENV[key.to_s] }
    vars.each { |key, value| ENV[key.to_s] = value }
    yield
  ensure
    original.each { |key, value| ENV[key.to_s] = value }
  end
end
