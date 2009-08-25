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

  RUBY_GNTP_NAME = 'ruby_gntp'
  RUBY_GNTP_VERSION = '0.1.3.1'

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

    @message = register_header(@app_name, @app_icon)
    @message << output_origin_headers

    @message << "Notifications-Count: #{@notifications.size}\r\n"
    @message << "\r\n"

    @notifications.each do |notification|
      name      = notification[:name]
      disp_name = notification[:disp_name] || name
      enabled   = notification[:enabled] || true
      icon      = notification[:icon]

      @message << "Notification-Name: #{name}\r\n"
      @message << "Notification-Enabled: #{enabled ? 'True' : 'False'}\r\n"
      @message << "Notification-Display-Name: #{disp_name}\r\n"
      @message << "#{handle_icon(icon, 'Notification')}\r\n"    if icon
    end

    @binaries.each {|binary|
      @message << output_binary(binary)
    }

    @message << "\r\n"

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
    @message << output_origin_headers

    @binaries.each {|binary|
      @message << output_binary(binary)
    }

    @message << "\r\n"

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
  def register_header(app_name, app_icon)
    message =  "#{get_gntp_header_start('REGISTER')}\r\n"
    message << "Application-Name: #{app_name}\r\n"
    message << "#{handle_icon(@app_icon, 'Application')}\r\n" if app_icon
  end

  #
  # outputs the notification header
  #
  def notify_header(app_name, name, title, text, sticky, icon)
    message =  "#{get_gntp_header_start('NOTIFY')}\r\n"
    message << "Application-Name: #{@app_name}\r\n"
    message << "Notification-Name: #{name}\r\n"
    message << "Notification-Title: #{title}\r\n"
    message << "Notification-Text: #{text}\r\n"            if text
    message << "Notification-Sticky: #{sticky}\r\n"        if sticky
    message << "#{handle_icon(icon, 'Notification')}\r\n"  if icon
  end

  def output_origin_headers
    message =  "Origin-Machine-Name: #{Socket.gethostname}\r\n"
    message << "Origin-Software-Name: #{RUBY_GNTP_NAME}\r\n"
    message << "Origin-Software-Version: #{RUBY_GNTP_VERSION}\r\n"

    platformname, platformversion = '', ''

    if ENV['OS']
      ver = `ver`
      if ver.index('[')
        matches = ver.scan(/(.*)\[+(.*)\]+/)[0]
        platformname, platformversion = matches[0], matches[1]
      else
        platformname, platformversion = 'Microsoft Windows', ver
      end
    else
      platformname, platformversion = `uname -s`, `uname -r`
    end

    message << "Origin-Platform-Name: #{platformname.strip}\r\n"
    message << "Origin-Platform-Version: #{platformversion.strip}\r\n"
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
    if File.exists?(icon) && @target_host != 'localhost'
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
    message =  "\r\n"
    message << "Identifier: #{binary[:uniqueid]}\r\n"
    message << "Length: #{binary[:size]}\r\n"
    message << "\r\n"
    message << "#{binary[:data]}\r\n"
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
