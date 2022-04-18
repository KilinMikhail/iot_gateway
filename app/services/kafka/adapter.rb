module Kafka
  class Adapter
    include Singleton

    def start_session
      @session_thread ||= Thread.new do
        consumer = client.consumer(group_id: ENV.fetch("KAFKA_GROUP_ID", "my-consumer"))
        
        consumer.subscribe(ENV.fetch("KAFKA_COMMAND_TOPIC", "device-command"))
      
        consumer.each_message do |message|
          data = JSON.parse(message.value)

          sensor = Sensor.find_by(name: data["sensorType"])

          if sensor.present?
            sensor.update(value: data["value"])

            Mqtt::MqttAdapter.instance.send_sensor_data(sensor)
          end
        end
      end
    end

    def restart_session
      stop_session
      start_session
    end

    def stop_session
      @session_thread.kill
      @session_thread = nil
    end

    def produce_sensor_data(sensor)
      topic = ENV.fetch("KAFKA_SENSOR_DATA_TOPIC", "device-info")
      message = {
        "sensorId" => sensor.number,
        "sensorType" => sensor.name,
        "messageType" => "INFO",
        "typeValue" => sensor.value_type,
        "value" => sensor.value
      }.to_json
      sensor_data_producer.produce(message, topic: topic)
      sensor_data_producer.deliver_messages
    end

    private

    def sensor_data_producer
      @client_producer ||= client.producer
    end

    def client
      @client ||= Kafka.new(ENV.fetch("KAFKA_ADDRESS", "127.0.0.1:9092"))
    end
  end
end
