require 'rails_helper'

RSpec.describe Google::GmailApi do
  describe '.enabled?' do
    it 'boolean casts USE_GMAIL_API' do
      with_modified_env USE_GMAIL_API: 'true' do
        expect(described_class.enabled?).to be true
      end

      with_modified_env USE_GMAIL_API: 'false' do
        expect(described_class.enabled?).to be false
      end
    end
  end

  describe '.client_for' do
    it 'builds a client from a refreshed access token' do
      channel = create(:channel_email, provider_config: { access_token: 'old-token' })
      refresh_service = instance_double(Google::RefreshOauthTokenService, access_token: 'fresh-token')

      allow(Google::RefreshOauthTokenService).to receive(:new).with(channel: channel).and_return(refresh_service)
      allow(Gmail::Client).to receive(:new).with(access_token: 'fresh-token')

      described_class.client_for(channel: channel)

      expect(Gmail::Client).to have_received(:new).with(access_token: 'fresh-token')
    end
  end

  describe '.authorization_error?' do
    it 'matches Gmail unauthorized and forbidden errors' do
      expect(described_class.authorization_error?(Google::Apis::AuthorizationError.new('Unauthorized', status_code: 401))).to be true
      expect(described_class.authorization_error?(Google::Apis::ClientError.new('Forbidden', status_code: 403))).to be true
      expect(described_class.authorization_error?(Google::Apis::ServerError.new('Server error', status_code: 500))).to be false
    end
  end
end
