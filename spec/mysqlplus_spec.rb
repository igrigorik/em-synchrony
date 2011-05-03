require "spec/helper/all"
require "mysqlplus"
require "em-mysqlplus"

describe EventMachine::MySQL do
  let(:error_class) { Mysql::Error }

  def establish_connection
    EventMachine::MySQL.new(host: "localhost")
  end

  it_should_behave_like "An EM::Synchrony SQL Client"

end
