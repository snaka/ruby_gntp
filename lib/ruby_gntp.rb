#!/usr/bin/ruby
#
# Ruby library for GNTP/1.0
#
# LICENSE:{{{
#  Copyright (c) 2009 snaka<snaka.gml@gmail.com>
#
#   The MIT License
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to deal
#   in the Software without restriction, including without limitation the rights
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#   copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#   THE SOFTWARE.
#
#   日本語訳(japanese):
#     http://sourceforge.jp/projects/opensource/wiki/licenses%2FMIT_license
#
#}}}
require 'socket'

$DEBUG = true

class TooFewParametersError < Exception
end

class GNTP
  attr_reader :app_name, :target_host, :target_port
  attr_reader :message if $DEBUG

  def initialize(app_name = 'Ruby/GNTP', host = 'localhost', port = 23053)
    @app_name    = app_name
    @target_host = host
    @target_port = port
  end

  #
  # register
  #
  def register(params)
    @app_name = params[:app_name]
    @notifies = params[:notifies]
    raise TooFewParametersError, "Need least one 'notification' for register" unless @notifies

    @app_icon = params[:app_icon]

    @message = <<EOF
GNTP/1.0 REGISTER NONE
Application-Name: #{@app_name}
Notifications-Count: #{@notifies.size}
EOF
    @message << "Application-Icon: #{@app_icon}\n" if @app_icon
    @message << "\n"

    @notifies.each do |notify|
      name      = notify[:name]
      disp_name = notify[:disp_name]
      enabled   = notify[:enabled]
      icon      = notify[:icon]

      @message += <<EOF
Notification-Name: #{name}
EOF
      @message << "Notification-Display-Name: #{disp_name}\n" if disp_name
      @message << "Notification-Enabled: #{enabled}\n"        if enabled
      @message << "Notification-Icon: #{icon}\n"              if icon
      @message << "\n"
    end

    unless (ret = send_and_recieve(@message))
      raise "Register failed"
    end
  end


  #
  # notify
  #
  def notify(params)
    name   = params[:name]
    raise TooFewParametersError, "Notification need 'name', 'title' parameters" unless name || title

    title  = params[:title]
    text   = params[:text]
    icon   = params[:icon] || get_notification_icon(name)
    sticky = params[:sticky]

    @message = <<EOF
GNTP/1.0 NOTIFY NONE
Application-Name: #{@app_name}
Notification-Name: #{name}
Notification-Title: #{title}
EOF
    @message << "Notification-Text: #{text}\n"     if text
    @message << "Notification-Sticky: #{sticky}\n" if sticky
    @message << "Notification-Icon: #{icon}\n"     if icon
    @message << "\n"

    unless (ret = send_and_recieve(@message))
      raise "Notify failed"
    end
  end

  private

  #
  # send and recieve
  #
  def send_and_recieve msg
    msg.gsub!(/\n/, "\r\n")
    print msg if $DEBUG

    sock = TCPSocket.open(@target_host, @target_port)
    sock.write msg

    ret = nil
    while rcv = sock.gets
      break if rcv == "\r\n"
      print ">#{rcv}" if $DEBUG
      ret = $1 if /GNTP\/1.0\s+-(\S+)/ =~ rcv
    end
    sock.close

    return 'OK' == ret
  end

  #
  # get notification icon
  #
  def get_notification_icon(name)
    notification = @notifies.find {|n| n[:name] == name}
    return nil unless notification
    return notification[:icon]
  end
end

#----------------------------
# self test code
if __FILE__ == $0
  growl = GNTP.new
  growl.register({
    :app_name => "Ruby/GNTP self test",
    :notifies => [{
      :name     => "hoge",
      :enabled  => true,
    }]
  })

  growl.notify({
    :name  => "hoge",
    :title => "GrowlTestです",
    :text  => "hogeほげ？",
    :icon  => "http://www.hatena.ne.jp/users/sn/snaka72/profile.gif"
  })
end

# vim: ts=2 sw=2 expandtab fdm=marker
