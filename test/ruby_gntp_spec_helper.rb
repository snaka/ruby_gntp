module GNTPExampleHelperMethods

  def create_stub_socket(ok_response, sended_messages)

    sock = {}

    stub(sock).write do |string|
      lines = []
      buf = StringIO.new(string)

      while line = buf.gets
        lines << line
      end

      sended_messages << lines
      ok_response.rewind
    end

    stub(sock).gets do
      ok_response.gets
    end

    stub(sock).close

    stub(TCPSocket).open do |host, port|
      sock[:host] = host
      sock[:port] = port
      sock
    end

    sock
  end

end
