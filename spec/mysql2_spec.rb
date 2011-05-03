require "spec/helper/all"

describe Mysql2::EM::Client do
  let(:error_class) { Mysql2::Error }

  def establish_connection
    Mysql2::EM::Client.new(host: "localhost")
  end

  it_should_behave_like "An EM::Synchrony SQL Client"

end
