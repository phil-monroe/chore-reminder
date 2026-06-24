require "test_helper"

class Oauth::ClientTest < ActiveSupport::TestCase
  test "valid with a client_id and at least one absolute redirect_uri" do
    client = Oauth::Client.new(client_id: "abc123", client_name: "Test", redirect_uris: ["https://example.com/callback"])

    assert client.valid?
  end

  test "invalid without a client_id" do
    client = Oauth::Client.new(redirect_uris: ["https://example.com/callback"])

    assert_not client.valid?
    assert_includes client.errors[:client_id], "can't be blank"
  end

  test "invalid with a duplicate client_id" do
    client = Oauth::Client.new(client_id: oauth_clients(:one).client_id, redirect_uris: ["https://example.com/callback"])

    assert_not client.valid?
    assert_includes client.errors[:client_id], "has already been taken"
  end

  test "invalid without any redirect_uris" do
    client = Oauth::Client.new(client_id: "abc123", redirect_uris: [])

    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "can't be blank"
  end

  test "invalid with a non-absolute redirect_uri" do
    client = Oauth::Client.new(client_id: "abc123", redirect_uris: ["not-a-url"])

    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must be absolute URIs"
  end

  test "invalid with a plain http redirect_uri on a non-local host" do
    client = Oauth::Client.new(client_id: "abc123", redirect_uris: ["http://attacker.example.com/callback"])

    assert_not client.valid?
    assert_includes client.errors[:redirect_uris], "must use https, or be localhost"
  end

  test "valid with a plain http redirect_uri on localhost" do
    client = Oauth::Client.new(client_id: "abc123", redirect_uris: ["http://localhost:8080/callback"])

    assert client.valid?
  end
end
