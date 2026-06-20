class Views::Admin::Users::NewMessage < Views::Base
  def initialize(user:)
    @user = user
  end

  def page_content
    link_to "← Back to #{@user.name}", admin_user_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    h1(class: "text-2xl font-bold text-gray-900 mb-6") { "Send a message to #{@user.name}" }

    div(class: "bg-white border border-gray-200 rounded-lg p-4") do
      form_with url: send_message_admin_user_path(@user), method: :post, class: "space-y-2" do |f|
        f.text_area :body, rows: 3, placeholder: "Type a one-off message to send right now…",
          class: "block w-full rounded-md border border-gray-300 px-3 py-2"
        f.submit "Send", class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
      end
    end
  end
end
