require 'ruby_gntp'

describe GNTP, "where not instanced" do 
  it "should can register" do
    GNTP.notify({
      :app_name => "Instant notify",
      :title    => "Instant notification", 
      :text     => "Instant notification available now.",
      :icon     => "http://www.hatena.ne.jp/users/sn/snaka72/profile.gif",
   })
  end
end

describe GNTP, "where send REGISTER request to local server" do
  before do
    @response = ""
  end

  it "should recieve OK response from server" do
    gntp = GNPT.new("spec")
    gntp.register({
    })
    @response.sould == <<EOS
OK
EOS 
  end
end
