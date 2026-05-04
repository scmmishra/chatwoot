class Email::SendOnEmailService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Email
  end

  def perform_reply
    return unless message.email_notifiable_message?

    return send_via_gmail_api if gmail_api_delivery?

    reply_mail = ConversationReplyMailer.with(account: message.account).email_reply(message).deliver_now
    Rails.logger.info("Email message #{message.id} sent with source_id: #{reply_mail.message_id}")
    message.update(source_id: reply_mail.message_id)
  rescue StandardError => e
    handle_delivery_error(e)
  end

  def gmail_api_delivery?
    channel.google? && channel.provider_config['access_token'].present? && Google::GmailApi.enabled?
  end

  def send_via_gmail_api
    delivery = ConversationReplyMailer.with(account: message.account).email_reply(message)
    reply_mail = delivery.message
    Google::GmailApi.client_for(channel: channel).send_message(reply_mail)

    Rails.logger.info("Email message #{message.id} sent with source_id: #{reply_mail.message_id}")
    message.update(source_id: reply_mail.message_id)
  end

  def handle_delivery_error(error)
    channel.authorization_error! if Google::GmailApi.authorization_error?(error)
    ChatwootExceptionTracker.new(error, account: message.account).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end
end
