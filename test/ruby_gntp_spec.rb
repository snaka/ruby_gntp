require '../lib/ruby_gntp'
require 'ruby_gntp_spec_helper'

# use Double Ruby for mock/stub framework.
Spec::Runner.configure do |conf|
  conf.mock_with :rr
end

# describe GNTP behavior
describe GNTP do
  include GNTPExampleHelperMethods

  DEFAULT_APP_NAME  = "Ruby/GNTP"
  NOTIFICATION_NAME = "TestApp"

  before do
    @sended_messages = []
    @ok_response = StringIO.new(["GNTP/1.0 -OK NONE\r\n", "\r\n"].join)
    @opened_socket = create_stub_socket(@ok_response, @sended_messages)
  end

  it "can register notifications with minimum params" do
    @gntp = GNTP.new
    @gntp.register :notifications => [{:name => NOTIFICATION_NAME}]

    [
      "GNTP/1.0 REGISTER NONE\r\n",
      "Application-Name: #{DEFAULT_APP_NAME}\r\n",
      "Notifications-Count: 1\r\n",
      "\r\n",
      "Notification-Name: #{NOTIFICATION_NAME}\r\n",
      "Notification-Display-Name: #{NOTIFICATION_NAME}\r\n",
      "Notification-Enabled: True\r\n"
    ].each {|expected_text| 
      @sended_messages.last.should include(expected_text) 
    }
  end

  it "can register notifications to remote host" do
    @gntp = GNTP.new "TestApp", "1.2.3.4", "password", 12345
    @gntp.register :notifications => [{:name => NOTIFICATION_NAME}]

    @opened_socket[:host].should == "1.2.3.4"
    @opened_socket[:port].should == 12345

    @sended_messages.last.first.should match(/GNTP\/1\.0 REGISTER NONE MD5:\S+\r\n/)
    [
      "Application-Name: TestApp\r\n",
      "Notifications-Count: 1\r\n",
      "\r\n",
      "Notification-Name: #{NOTIFICATION_NAME}\r\n",
      "Notification-Display-Name: #{NOTIFICATION_NAME}\r\n",
      "Notification-Enabled: True\r\n"
    ].each {|expected_text| 
      @sended_messages.last.should include(expected_text) 
    }
  end

  it "can notify with minimum params" do
    @gntp = GNTP.new
    @gntp.register :notifications => [{:name => NOTIFICATION_NAME}]
    @gntp.notify :name => NOTIFICATION_NAME

    [
      "GNTP/1.0 NOTIFY NONE\r\n",
      "Application-Name: #{DEFAULT_APP_NAME}\r\n",
      "Notification-Name: #{NOTIFICATION_NAME}\r\n",
      "Notification-Title: \r\n"
    ].each {|expected_text| 
      @sended_messages.last.should include(expected_text) 
    }
  end

end
