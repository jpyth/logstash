# encoding: utf-8
require "logstash/inputs/threadable"
require "logstash/namespace"
require "socket" # for Socket.gethostname

# Generate random log events.
#
# The general intention of this is to test performance of plugins.
#
# An event is generated first
class LogStash::Inputs::Generator < LogStash::Inputs::Threadable
  config_name "generator"
  milestone 3

  default :codec, "plain"

  # The message string to use in the event.
  #
  # If you set this to 'stdin' then this plugin will read a single line from
  # stdin and use that as the message string for every event.
  #
  # Otherwise, this value will be used verbatim as the event message.
  config :message, :validate => :string, :default => "Hello world!"

  # The lines to emit, in order. This option cannot be used with the 'message'
  # setting.
  #
  # Example:
  #
  #     input {
  #       generator {
  #         lines => [
  #           "line 1",
  #           "line 2",
  #           "line 3"
  #         ]
  #         # Emit all lines 3 times.
  #         count => 3
  #       }
  #     }
  #
  # The above will emit "line 1" then "line 2" then "line", then "line 1", etc...
  config :lines, :validate => :array

  # Set how many messages should be generated.
  #
  # The default, 0, means generate an unlimited number of events.
  config :count, :validate => :number, :default => 0

  # Set delay(seconds) between generated events.
  #
  # The default, 0, means generate events as quickly as possible.
  config :delay, :validate => :number, :default => 0

  # Set whether to include sequence number of generated events in event
  #
  #The default, true, means each event will include field 'sequence' to indicate count of generated messages. 
  config :log_sequence, :validate => :boolean, :default => true

  public
  def register
    @host = Socket.gethostname
    @count = @count.first if @count.is_a?(Array)
  end # def register

  def run(queue)
    number = 0

    if @message == "stdin"
      @logger.info("Generator plugin reading a line from stdin")
      @message = $stdin.readline
      @logger.debug("Generator line read complete", :message => @message)
    end
    @lines = [@message] if @lines.nil?

    while !finished? && (@count <= 0 || number < @count)
      @lines.each do |line|
        @codec.decode(line.clone) do |event|
          if @delay > 0  
            sleep(@delay)
          end
          decorate(event)
          event["host"] = @host
          if @log_sequence
            event["sequence"] = number
          end
          queue << event
        end
      end
      if @log_sequence
        number += 1
      end
    end # loop

    if @codec.respond_to?(:flush)
      @codec.flush do |event|
        decorate(event)
        event["host"] = @host
        queue << event
      end
    end
  end # def run

  public
  def teardown
    @codec.flush do |event|
      decorate(event)
      event["host"] = @host
      queue << event
    end
    finished
  end # def teardown
end # class LogStash::Inputs::Generator
