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
#   Japanese:
#   http://sourceforge.jp/projects/opensource/wiki/licenses%2FMIT_license
#
#}}}
require 'socket'
require 'digest/md5'

#$DEBUG = true

class TooFewParametersError < Exception
end

class GNTP
  attr_reader :app_name, :target_host, :target_port, :password
  attr_reader :message if $DEBUG

  def initialize(app_name = 'Ruby/GNTP', host = 'localhost', password = '', port = 23053)
    @app_name    = app_name
    @target_host = host
    @target_port = port
    @password = password
  end

  #
  # register
  #
  def register(params)
    @notifications = params[:notifications]
    raise TooFewParametersError, "Need least one 'notification' for register" unless @notifications

    @app_icon = params[:app_icon]
    @binaries = []

    @message = register_header(@app_name, @app_icon, @notifications.size)

    @notifications.each do |notification|
      name      = notification[:name]
      disp_name = notification[:disp_name]
      enabled   = notification[:enabled] || true
      icon      = notification[:icon]

      @message << "Notification-Name: #{name}\n"
      @message << "Notification-Display-Name: #{disp_name}\n" if disp_name
      @message << "Notification-Enabled: #{enabled}\n"        if enabled
      @message << "#{handle_icon(icon, 'Notification')}\n"    if icon
    end

    @binaries.each {|binary|
      @message << output_binary(binary)
    }

    @message << "\n"

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

    @binaries = []

    @message = notify_header(app_name, name, title, text, sticky, icon)

    @binaries.each {|binary|
      @message << output_binary(binary)
    }

    @message << "\n"

    unless (ret = send_and_recieve(@message))
      raise "Notify failed"
    end
  end


  #
  # instant notification
  #
  def self.notify(params)
    growl = GNTP.new(params[:app_name])
    notification = params
    notification[:name] = params[:app_name] || "Ruby/GNTP notification"
    growl.register(:notifications => [
      :name => notification[:name]
    ])
    growl.notify(notification)
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
    notification = @notifications.find {|n| n[:name] == name}
    return nil unless notification
    return notification[:icon]
  end

  #
  # outputs the registration header
  #
  def register_header(app_name, app_icon, notifications_size)
    message =  "#{get_gntp_header_start('REGISTER')}\n"
    message << "Application-Name: #{app_name}\n"
    message << "#{handle_icon(@app_icon, 'Application')}\n" if app_icon
    message << "Notifications-Count: #{notifications_size}\n"
    message << "\n"
  end

  #
  # outputs the notification header
  #
  def notify_header(app_name, name, title, text, sticky, icon)
    message =  "#{get_gntp_header_start('NOTIFY')}\n"
    message << "Application-Name: #{@app_name}\n"
    message << "Notification-Name: #{name}\n"
    message << "Notification-Title: #{title}\n"
    message << "Notification-Text: #{text}\n"            if text
    message << "Notification-Sticky: #{sticky}\n"        if sticky
    message << "#{handle_icon(icon, 'Notification')}\n"  if icon
  end

  #
  # get start of the GNTP header
  #
  def get_gntp_header_start(type)
    if @password.empty?
      "GNTP/1.0 #{type} NONE"
    else
      saltvar = Time.now.to_s
      salt = Digest::MD5.digest(saltvar)
      salthash = Digest::MD5.hexdigest(saltvar)
      key = Digest::MD5.digest("#{@password}#{salt}")
      keyhash = Digest::MD5.hexdigest(key)
      "GNTP/1.0 #{type} NONE MD5:#{keyhash}.#{salthash}"
    end
  end

  #
  # figure out how to handle the icon
  #   a URL icon just gets put into the header
  #   a file icon gets read and stored, ready to be appended to the end of the request
  #
  def handle_icon(icon, type)
    if File.exists?(icon)
      file = File.new(icon)
      data = file.read
      size = data.length
      if size > 0
        binary = {
          :size => size,
          :data => data,
          :uniqueid => Digest::MD5.hexdigest(data)
        }
        @binaries << binary
        "#{type}-Icon: x-growl-resource://#{binary[:uniqueid]}"
      end
    else
      "#{type}-Icon: #{icon}"
    end
  end

  #
  # outputs any binary data to be sent
  #
  def output_binary(binary)
<<EOF

Identifier: #{binary[:uniqueid]}
Length: #{binary[:size]}

#{binary[:data]}
EOF
  end
end

#----------------------------
# self test code
if __FILE__ == $0
  #--- Use standard notification method ('register' first then 'notify')
  growl = GNTP.new("Ruby/GNTP self test")
  growl.register({:notifications => [{
      :name     => "notify",
      :enabled  => true,
  }]})

  growl.notify({
    :name  => "notify",
    :title => "Congraturation",
    :text  => "Congraturation! You are successful install ruby_gntp.",
    :icon  => "http://www.hatena.ne.jp/users/sn/snaka72/profile.gif",
    :sticky=> true,
  })

  #--- Use instant notification method (just 'notify')
  GNTP.notify({
    :app_name => "Instant notify",
    :title    => "Instant notification", 
    :text     => "Instant notification available now.",
    :icon     => "http://www.hatena.ne.jp/users/sn/snaka72/profile.gif",
  })
end

# vim: ts=2 sw=2 expandtab fdm=marker
