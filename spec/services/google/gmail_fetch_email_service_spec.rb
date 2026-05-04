require 'rails_helper'

RSpec.describe Google::GmailFetchEmailService do
  include ActionMailbox::TestHelper

  let(:account) { create(:account) }
  let(:channel) do
    create(
      :channel_email, :imap_email,
      account: account,
      provider: 'google',
      provider_config: { access_token: 'access-token', refresh_token: 'refresh-token' }
    )
  end
  let(:gmail) { instance_double(Gmail::Client) }
  let(:gmail_message) { instance_double(Google::Apis::GmailV1::Message, id: 'gmail-message-id') }
  let(:raw_email) { Rails.root.join('spec/fixtures/files/only_text.eml').read }
  let(:raw_gmail_message) { Base64.urlsafe_encode64(raw_email, padding: false) }

  before do
    allow(Google::GmailApi).to receive(:client_for).with(channel: channel).and_return(gmail)
  end

  describe '#perform' do
    it 'lists inbox messages after the interval and returns parsed mail objects' do
      travel_to '2026-05-04 10:00'.to_datetime do
        allow(gmail).to receive(:fetch_all_messages) do |&block|
          block.call(nil)
          [gmail_message]
        end
        allow(gmail).to receive(:list_messages).with(page_token: nil, query: 'after:2026/05/03')
        allow(gmail).to receive(:raw_message).with('gmail-message-id').and_return(raw_gmail_message)

        result = described_class.new(channel: channel, interval: 1).perform

        expect(result.length).to eq(1)
        expect(result.first).to be_a(Mail::Message)
        expect(result.first.message_id).to eq(Mail.read_from_string(raw_email).message_id)
        expect(gmail).to have_received(:list_messages).with(page_token: nil, query: 'after:2026/05/03')
        expect(gmail).to have_received(:raw_message).with('gmail-message-id')
      end
    end

    it 'skips raw messages already imported by RFC822 message id' do
      email_object = Mail.read_from_string(raw_email)
      create(:message, source_id: email_object.message_id, account: account, inbox: channel.inbox)

      allow(gmail).to receive(:fetch_all_messages).and_return([gmail_message])
      allow(gmail).to receive(:raw_message).with('gmail-message-id').and_return(raw_gmail_message)

      result = described_class.new(channel: channel).perform

      expect(result).to be_empty
      expect(gmail).to have_received(:raw_message).with('gmail-message-id')
    end
  end
end
