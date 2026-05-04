require 'google/apis/errors'
require 'gmail/client'

module Google::GmailApi
  LEGACY_MAIL_SCOPE = 'https://mail.google.com/'.freeze
  GMAIL_MODIFY_SCOPE = 'https://www.googleapis.com/auth/gmail.modify'.freeze
  OAUTH_SCOPE_PREFIX = 'email profile'.freeze
  AUTHORIZATION_STATUS_CODES = [401, 403].freeze

  def self.enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('USE_GMAIL_API', false))
  end

  def self.oauth_scope
    "#{OAUTH_SCOPE_PREFIX} #{enabled? ? GMAIL_MODIFY_SCOPE : LEGACY_MAIL_SCOPE}"
  end

  def self.client_for(channel:)
    access_token = Google::RefreshOauthTokenService.new(channel: channel).access_token
    Gmail::Client.new(access_token: access_token)
  end

  def self.authorization_error?(error)
    error.is_a?(Google::Apis::AuthorizationError) ||
      (error.is_a?(Google::Apis::Error) && AUTHORIZATION_STATUS_CODES.include?(error.status_code))
  end
end
