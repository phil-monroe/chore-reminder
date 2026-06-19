class Views::Users::Conversation < Views::Base
  def initialize(user:, messages:)
    @user = user
    @messages = messages
  end

  def page_content
    link_to "← Back to #{@user.name}", user_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    h1(class: "text-2xl font-bold text-gray-900 mb-6") { "Conversation with #{@user.name}" }

    div(class: "bg-gray-50 border border-gray-200 rounded-lg p-4 space-y-2 mb-6 max-h-[60vh] overflow-y-auto",
      data: {controller: "scroll-to-bottom"}) do
      if @messages.empty?
        p(class: "text-gray-500 text-sm") { "No messages yet." }
      else
        @messages.each { |message| message_bubble(message) }
      end
    end

    div(class: "bg-white border border-gray-200 rounded-lg p-4") do
      p(class: "text-gray-500 text-sm mb-2") { "Simulate a text reply from #{@user.name} (DONE, SKIP, NEXT, LIST, or ADD <task name>):" }
      form_with url: send_inbound_message_user_path(@user), method: :post, class: "space-y-2" do |f|
        f.text_area :body, rows: 2, required: true, placeholder: "DONE",
          class: "block w-full rounded-md border border-gray-300 px-3 py-2"
        f.submit "Send", class: "bg-blue-600 text-white px-3 py-1.5 rounded-md text-sm hover:bg-blue-700"
      end
    end
  end

  private

  URL_PATTERN = %r{(https?://\S+)}

  def message_bubble(message)
    outbound = message.outbound?

    div(class: "flex #{outbound ? "justify-start" : "justify-end"}") do
      div(class: "max-w-[75%] rounded-2xl px-4 py-2 shadow-sm #{outbound ? "bg-white text-gray-900" : "bg-blue-600 text-white"}") do
        p(class: "text-sm whitespace-pre-wrap break-words") { linkify(message.body) }
        p(class: "text-xs mt-1 #{outbound ? "text-gray-400" : "text-blue-100"}") { message.created_at.strftime("%b %-d, %-I:%M %p") }
      end
    end
  end

  def linkify(body)
    body.split(URL_PATTERN).each do |part|
      if part.match?(URL_PATTERN)
        a(href: part, target: "_blank", rel: "noopener noreferrer", class: "underline break-all") { part }
      else
        plain part
      end
    end
  end
end
