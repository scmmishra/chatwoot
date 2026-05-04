require 'rails_helper'

RSpec.describe Gmail::Client do
  let(:service) { double }
  let(:client) { described_class.new(access_token: 'access-token', service: service) }

  before do
    allow(service).to receive(:authorization=)
  end

  it 'authorizes the generated Gmail service with the access token' do
    client

    expect(service).to have_received(:authorization=).with('access-token')
  end

  it 'lists inbox messages with the expected Gmail query options' do
    allow(service).to receive(:list_user_messages)

    client.list_messages(page_token: 'next-token', query: 'after:2026/05/03')

    expect(service).to have_received(:list_user_messages).with(
      'me',
      label_ids: ['INBOX'],
      q: 'after:2026/05/03',
      max_results: 500,
      page_token: 'next-token',
      include_spam_trash: false
    )
  end

  it 'uses fetch_all with Gmail message items' do
    allow(service).to receive(:fetch_all)

    client.fetch_all_messages { |_page_token| nil }

    expect(service).to have_received(:fetch_all).with(items: :messages)
  end

  it 'fetches raw RFC822 Gmail message content' do
    gmail_message = instance_double(Google::Apis::GmailV1::Message, raw: 'raw-message')
    allow(service).to receive(:get_user_message).and_return(gmail_message)

    result = client.raw_message('gmail-message-id')

    expect(result).to eq('raw-message')
    expect(service).to have_received(:get_user_message).with('me', 'gmail-message-id', format: 'raw')
  end

  it 'sends RFC822 content via upload_source' do
    mail = instance_double(Mail::Message, encoded: 'encoded-rfc822')
    allow(service).to receive(:send_user_message)

    client.send_message(mail)

    expect(service).to have_received(:send_user_message).with(
      'me',
      upload_source: an_instance_of(StringIO),
      content_type: 'message/rfc822'
    )
  end
end
