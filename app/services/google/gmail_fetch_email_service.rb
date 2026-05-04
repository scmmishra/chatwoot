require 'base64'

class Google::GmailFetchEmailService
  pattr_initialize [:channel!, :interval]

  def perform
    if channel.provider_config['access_token'].blank?
      log_info('Skipping Gmail API fetch because access token is missing')
      return []
    end

    log_info("Starting Gmail API fetch with query=#{query.inspect}, interval=#{interval || 1}")

    total_messages = 0
    skipped_messages = 0
    inbound_emails = fetch_messages.filter_map do |message|
      total_messages += 1
      mail = process_message(message.id)
      skipped_messages += 1 if mail.blank?
      mail
    end

    log_info("Completed Gmail API fetch. listed=#{total_messages}, imported=#{inbound_emails.length}, skipped=#{skipped_messages}")
    inbound_emails
  end

  private

  def fetch_messages
    gmail.fetch_all_messages do |page_token|
      log_info("Listing Gmail messages. page_token=#{page_token.present? ? 'present' : 'initial'}")
      gmail.list_messages(page_token: page_token, query: query)
    end
  end

  def gmail
    @gmail ||= Google::GmailApi.client_for(channel: channel)
  end

  def process_message(message_id)
    if message_id.blank?
      log_info('Skipping Gmail message because Gmail message id is blank')
      return
    end

    log_info("Fetching raw Gmail message. gmail_message_id=#{message_id}")
    raw_message = gmail.raw_message(message_id)
    mail = build_mail_from_raw(raw_message)
    log_info("Parsed Gmail message. gmail_message_id=#{message_id}, rfc822_message_id=#{mail.message_id}")

    if email_already_present?(mail.message_id)
      log_info("Skipping already imported Gmail message. gmail_message_id=#{message_id}, rfc822_message_id=#{mail.message_id}")
      return
    end

    mail_info_logger(mail, message_id)
    log_info("Queued Gmail message for mailbox processing. gmail_message_id=#{message_id}, rfc822_message_id=#{mail.message_id}")
    mail
  end

  def build_mail_from_raw(raw_message)
    Mail.read_from_string(raw_email_content(raw_message))
  rescue ArgumentError => e
    log_info("Failed to decode raw Gmail message. raw_length=#{raw_message.to_s.length}, error=#{e.message}")
    raise
  end

  def raw_email_content(raw_message)
    raw_message = raw_message.to_s
    return raw_message if raw_message.match?(/\A[A-Za-z0-9-]+:/)

    Base64.urlsafe_decode64(padded_raw_message(raw_message))
  end

  def padded_raw_message(raw_message)
    normalized_raw_message = raw_message.to_s.delete("\r\n")
    padding = (4 - (normalized_raw_message.length % 4)) % 4

    "#{normalized_raw_message}#{'=' * padding}"
  end

  def email_already_present?(message_id)
    channel.inbox.messages.find_by(source_id: message_id).present?
  end

  def mail_info_logger(inbound_mail, gmail_message_id)
    return if Rails.env.test?

    Rails.logger.info("
      #{channel.provider} Email id: #{inbound_mail.from} - message_source_id: #{inbound_mail.message_id} - gmail id: #{gmail_message_id}")
  end

  def log_info(message)
    return if Rails.env.test?

    Rails.logger.info("[GMAIL_API_FETCH] inbox_id=#{channel.inbox.id}, channel_id=#{channel.id}, email=#{channel.email} - #{message}")
  end

  def query
    "after:#{since}"
  end

  def since
    previous_day = Time.zone.today - (interval || 1).to_i
    previous_day.strftime('%Y/%m/%d')
  end
end
