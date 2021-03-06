require 'rails_helper'

RSpec.describe Api::V1::TwilioController, type: :controller do

  let(:from_number) { '+12073328710' }
  let(:to_number) { '+14193860121' }
  let(:msg) { 'I need a ride' }
  let(:response_text) { 'On our way!' }
  let!(:ride_zone) { create :ride_zone, phone_number: to_number }
  let(:user) { create :user, phone_number: from_number }

  it "works not logged in" do
    post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
    expect(response).to be_successful
  end

  context "logged in as a driver" do
    login_driver

    describe 'POST sms' do

      it 'works' do
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(response).to be_successful
      end

      it 'creates user' do
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(User.last.phone_number).to eq(from_number)
      end

      it 'creates message' do
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(Message.first.body).to eq msg
      end

      it 'creates conversation' do
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(Conversation.last.from_phone).to eq from_number
      end

      it 'reuses conversation' do
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        c = Conversation.last
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(Conversation.count).to eq(1)
        expect(Message.last.conversation_id).to eq(c.id)
      end

      it 'does not reuse closed conversation' do
        c = create :conversation, user: user, from_phone: from_number, ride_zone: ride_zone, status: Conversation.statuses[:closed]
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(Conversation.count).to eq(2)
        expect(Message.last.conversation_id).to_not eq(c.id)
      end

      it 'responds with bot response' do
        expect_any_instance_of(ConversationBot).to receive(:response) { response_text }
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(response.body.include?(response_text)).to be_truthy
      end

      it 'does not respond if conversation is help_needed' do
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        Conversation.last.update_attribute(:status, :help_needed)
        expect_any_instance_of(ConversationBot).to_not receive(:response)
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(response.body).to be_empty
      end

      it 'handles bad to phone' do
        allow(RideZone).to receive(:find_by_phone_number_normalized).and_return(nil)
        post :sms, params: {'From' => from_number, 'To' => to_number, 'Body' => msg}
        expect(response).to be_successful  # we 200 back to Twilio
        expect(response.body.include?(TwilioService::CONFIG_ERROR_MSG)).to be_truthy
      end
    end
  end

end



