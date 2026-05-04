require 'base64'

class Google::GmailFetchEmailService
  pattr_initialize [:channel!, :interval]

  def perform
    return [] if channel.provider_config['access_token'].blank?

    messages = gmail.fetch_all_messages do |page_token|
      gmail.list_messages(page_token: page_token, query: query)
    end

    messages.filter_map do |message|
      process_message(message.id)
    end
  end

  private

  def gmail
    @gmail ||= Google::GmailApi.client_for(channel: channel)
  end

  def process_message(message_id)
    mail = build_mail_from_raw(gmail.raw_message(message_id))
    return if email_already_present?(mail.message_id)

    mail_info_logger(mail, message_id)
    mail
  end

  def build_mail_from_raw(raw_message)
    Mail.read_from_string(Base64.urlsafe_decode64(raw_message))
  end

  def email_already_present?(message_id)
    channel.inbox.messages.find_by(source_id: message_id).present?
  end

  def mail_info_logger(inbound_mail, gmail_message_id)
    return if Rails.env.test?

    Rails.logger.info("
      #{channel.provider} Email id: #{inbound_mail.from} - message_source_id: #{inbound_mail.message_id} - gmail id: #{gmail_message_id}")
  end

  def query
    "after:#{since}"
  end

  def since
    previous_day = Time.zone.today - (interval || 1).to_i
    previous_day.strftime('%Y/%m/%d')
  end
end
