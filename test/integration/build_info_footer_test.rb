require "test_helper"

class BuildInfoFooterTest < ActionDispatch::IntegrationTest
  test "shows the short sha and ref, revealing the full message in a tappable details element when GIT_SHA is set" do
    with_env(GIT_SHA: "abc1234def5678", GIT_REF: "main", GIT_COMMIT_MESSAGE: "Add build info footer") do
      get admin_root_path
    end

    assert_select "#build-info details > summary.text-gray-300", text: "abc1234 @ main"
    assert_select "#build-info details > p.text-gray-400", text: "Add build info footer"
  end

  test "shows a placeholder when GIT_SHA is not set (e.g. local dev)" do
    with_env(GIT_SHA: nil) do
      get admin_root_path
    end

    assert_select "span.text-gray-300", text: "dev build"
    assert_select "#build-info details", count: 0
  end

  test "falls back to a plain (non-tappable) span without a ref or message when only GIT_SHA is set" do
    with_env(GIT_SHA: "abc1234def5678", GIT_REF: nil, GIT_COMMIT_MESSAGE: nil) do
      get admin_root_path
    end

    assert_select "span.text-gray-300", text: "abc1234"
    assert_select "#build-info details", count: 0
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
