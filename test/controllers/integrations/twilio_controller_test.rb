require "test_helper"

class Integrations::TwilioControllerTest < ActionDispatch::IntegrationTest
  test "a signed request from a known number runs the command and replies with TwiML" do
    user = users(:one)
    params = {From: user.phone_number, Body: "NEXT"}

    post twilio_sms_inbound_webhook_path, params: params, headers: signature_headers_for(params)

    assert_response :success
    assert_includes response.media_type, "xml"
    assert_includes response.body, tasks(:one).name
  end

  test "a signed request from an unrecognized number gets a generic reply" do
    params = {From: "+15555550199", Body: "NEXT"}

    post twilio_sms_inbound_webhook_path, params: params, headers: signature_headers_for(params)

    assert_response :success
    assert_includes response.body, "don't recognize this number"
  end

  test "a request with a missing or invalid signature is rejected" do
    user = users(:one)

    post twilio_sms_inbound_webhook_path,
      params: {From: user.phone_number, Body: "NEXT"},
      headers: {"X-Twilio-Signature" => "not-the-real-signature"}

    assert_response :forbidden
  end

  private

  def signature_headers_for(params)
    url = twilio_sms_inbound_webhook_url(host: "www.example.com")
    signature = Twilio::Security::RequestValidator.new(ENV.fetch("TWILIO_AUTH_TOKEN"))
      .build_signature_for(url, params.transform_keys(&:to_s))

    {"X-Twilio-Signature" => signature}
  end
end
