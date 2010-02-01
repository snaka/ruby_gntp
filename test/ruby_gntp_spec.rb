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
  NOTIFICATION_NAME = "Notify"
  NOTIFICATION_NAME2 = "Notify2"
  NOTIFICATION_NAME3 = "Notify3"

  before do
    @sended_messages = []
    @ok_response = StringIO.new(["GNTP/1.0 -OK NONE\r\n", "\r\n"].join)
    @opened_socket = create_stub_socket(@ok_response, @sended_messages)
  end

  it "can register notification with minimum params" do
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

  #
  it "can register many notifications" do
    @gntp = GNTP.new
    @gntp.register :notifications => [
      {:name => NOTIFICATION_NAME},
      {:name => NOTIFICATION_NAME2},
    ]

    @sended_messages.first.should == [
      "GNTP/1.0 REGISTER NONE\r\n",
      "Application-Name: #{DEFAULT_APP_NAME}\r\n",
      "Origin-Machine-Name: #{Socket.gethostname}\r\n",
      "Origin-Software-Name: #{GNTP::RUBY_GNTP_NAME}\r\n",
      "Origin-Software-Version: #{GNTP::RUBY_GNTP_VERSION}\r\n",
      "Origin-Platform-Name: Windows\r\n",
      "Origin-Platform-Version: 0.0\r\n",
      "Notifications-Count: 2\r\n",
      "\r\n",
      "Notification-Name: #{NOTIFICATION_NAME}\r\n",
      "Notification-Display-Name: #{NOTIFICATION_NAME}\r\n",
      "Notification-Enabled: True\r\n",
      "\r\n",
      "Notification-Name: #{NOTIFICATION_NAME2}\r\n",
      "Notification-Display-Name: #{NOTIFICATION_NAME2}\r\n",
      "Notification-Enabled: True\r\n",
      "\r\n",
    ]

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

  it "should callback when notify clicked" do
    # prepare callback msg
    @opened_socket.add [
      "GNTP/1.0 -CALLBACK NONE\r\n",
      "Notification-Callback-Result: CLICKED\r\n",
      "Notification-Callback-Context: hoge\r\n",
      "Notification-Callback-Context-Type: fuga\r\n",
      "\r\n",
    ].join

    callback_called = false
    msg = {}

    @gntp = GNTP.new
    @gntp.register :notifications => [{:name => NOTIFICATION_NAME}]
    @gntp.notify(:name => NOTIFICATION_NAME) do |response|
      sleep 1
      callback_called = true
      msg = response
    end

    [
      "Notification-Callback-Context: (none)\r\n",
      "Notification-Callback-Context-Type: (none)\r\n"
    ].each {|expected_text| 
      @sended_messages.last.should include(expected_text) 
    }

    # wait for callback called
    sleep 3
    callback_called.should be_true
    msg[:callback_result].should        == 'CLICKED'
    msg[:callback_context].should       == 'hoge'
    msg[:callback_context_type].should  == 'fuga'
  end

  it "should not send 'Notification-Callback-*' header when block parameter has not given" do
    @gntp = GNTP.new
    @gntp.register :notifications => [{:name => NOTIFICATION_NAME}]
    @gntp.notify :name => NOTIFICATION_NAME

    [
      "Notification-Callback-Context: (none)\r\n",
      "Notification-Callback-Context-Type: (none)\r\n"
    ].each {|expected_text| 
      @sended_messages.last.should_not include(expected_text) 
    }
  end

  it "should send 'Notification-Callback-*' header when block parameter has not given, but supply :callback_* parameter given" do
    @gntp = GNTP.new
    @gntp.register :notifications => [{:name => NOTIFICATION_NAME}]
    @gntp.notify :name                  => NOTIFICATION_NAME, 
                 :callback_context      => 'hoge',
                 :callback_context_type => 'text'

    [
      "Notification-Callback-Context: hoge\r\n",
      "Notification-Callback-Context-Type: text\r\n"
    ].each {|expected_text| 
      @sended_messages.last.should include(expected_text) 
    }
  end

  it "should send instantly" do
    GNTP.notify :app_name => "App", :title => "title", :text => "text message"
  end

end
