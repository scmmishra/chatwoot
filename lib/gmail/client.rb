require 'google/apis/gmail_v1'
require 'stringio'

class Gmail::Client
  USER_ID = 'me'.freeze
  RFC822_CONTENT_TYPE = 'message/rfc822'.freeze

  def initialize(access_token:, service: nil)
    @service = service || Google::Apis::GmailV1::GmailService.new
    @service.authorization = access_token
  end

  def fetch_all_messages(&)
    service.fetch_all(items: :messages, &)
  end

  def list_messages(page_token:, query:)
    service.list_user_messages(
      USER_ID,
      label_ids: ['INBOX'],
      q: query,
      max_results: 500,
      page_token: page_token,
      include_spam_trash: false
    )
  end

  def raw_message(message_id)
    service.get_user_message(USER_ID, message_id, format: 'raw').raw
  end

  def send_message(mail)
    service.send_user_message(
      USER_ID,
      upload_source: StringIO.new(mail.encoded),
      content_type: RFC822_CONTENT_TYPE
    )
  end

  private

  attr_reader :service
end
