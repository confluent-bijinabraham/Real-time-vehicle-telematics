# Real-time vehicle telematics



This demo guides you through the process of utilizing telemetry events to extract user insights using confluent kafka.

## Architecture Diagram

This demo makes use of a Python data generator script to transmit telemetry events from the game server to Confluent Cloud. The events are then processed through KSQLDB, where they are enriched to perform real-time calculations to determine the average kills per death for players. The enriched data can be sent to any external system of your choice for further analysis using a connector plugin.

<div align="center"> 
  <img src="images/RT metrics architecture.jpeg" width =100% heigth=100%>
</div>



# Requirements

In order to successfully complete this demo you need to install few tools before getting started.

- If you don't have a Confluent Cloud account, sign up for a free trial [here](https://www.confluent.io/confluent-cloud/tryfree).
- Install Confluent Cloud CLI by following the instructions [here](https://docs.confluent.io/confluent-cli/current/install.html).
- Please follow the instructions to install Terraform if it is not already installed on your system.[here](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  
- This demo uses Python 3.9.13 version.
- This demo uses python modules. You can install this module through `pip`.
  ```
  pip3 install modulename
  ```

## Prerequisites

### Confluent Cloud

1. Sign up for a Confluent Cloud account [here](https://www.confluent.io/get-started/).
1. After verifying your email address, access Confluent Cloud sign-in by navigating [here](https://confluent.cloud).
1. When provided with the _username_ and _password_ prompts, fill in your credentials.

   > **Note:** If you're logging in for the first time you will see a wizard that will walk you through the some tutorials. Minimize this as you will walk through these steps in this guide.

1. Create Confluent Cloud API keys by following the steps in UI.Click on the button that is present on the right top section and click on Cloud API Key.
<div align="center"> 
  <img src="images/cloud1.jpeg" width =100% heigth=100%>
</div>

 Now Click Add Key to generate API keys and store it as we will be using that key in this demo.
 <div align="center"> 
  <img src="images/cloud2.jpeg" width =100% heigth=100%>
</div>
    
   > **Note:** This is different than Kafka cluster API keys.

## Setup

1. This demo uses Terraform  to spin up resources that are needed.

2. Update the `terraform/variables.tf` file for the following variables with your Cloud API credentials.

```
variable "confluent_cloud_api_key" {
  
  default = " Replace with your API Key created during pre-requsite"   
}

variable "confluent_cloud_api_secret" {
  default = "Replace with your API Key created during pre-requsite"   
}
```
 ### Build your cloud infrastructure

1. Navigate to the repo's terraform directory.
   ```bash
   cd terraform
   ```

1. Initialize Terraform within the directory.
   ```
   terraform init
   ```

1. Apply the plan to create the infrastructure.

   ```
   terraform apply 
   ```

   > **Note:** Read the `main.tf` configuration file [to see what will be created](./terraform/main.tf).


 # Demo
## Execute Python Script to Generate Mock Data

Please run the Python script located in the Python script folder. Before running it, make sure to replace the below mentioned  configuration settings in the code to point to your Confluent Cloud cluster that you created.
    
```
BOOTSTRAP_SERVERS = ''  # Replace with your Confluent Cloud bootstrap servers
SASL_USERNAME = ''  # Replace with your Confluent Cloud API key
SASL_PASSWORD = ''  # Replace with your Confluent Cloud API secret
```
To obtain the following details, navigate to the Clients section on the Confluent Cloud UI and select Python as the script type. From there, you can copy the bootstrap server and API Key details and replace them in the code.

<div align="center"> 
  <img src="images/Client.jpeg" width =100% heigth=100%>
</div>

Please run the Python script using the following syntax:

```
python mock_data_generator.py
```


## Enrich Data Streams with ksqlDB

Now that you have data flowing through Confluent, you can now easily build stream processing applications using ksqlDB. You are able to continuously transform, enrich, join, and aggregate your data using simple SQL syntax. You can gain value from your data directly from Confluent in real-time. Also, ksqlDB is a fully managed service within Confluent Cloud with a 99.9% uptime SLA. You can now focus on developing services and building your data pipeline while letting Confluent manage your resources for you.

<B>This section will involve the creation of a KStream and KTable that will calculate the kills to death ratio for each player in real-time using simple SQL like commands.<B>

If you’re interested in learning more about ksqlDB and the differences between streams and tables, I recommend reading these two blogs [here](https://www.confluent.io/blog/kafka-streams-tables-part-3-event-processing-fundamentals/) and [here](https://www.confluent.io/blog/how-real-time-stream-processing-works-with-ksqldb/).

1. On the navigation menu click on **ksqlDB** and step into the cluster you created during setup.
   To write streaming queries against topics, you will need to register the topics with ksqlDB as a stream or table.

2. **VERY IMPORTANT** -- at the bottom of the editor, set `auto.offset.reset` to `earliest`, or enter the statement:

   ```SQL
   SET 'auto.offset.reset' = 'earliest';
   ```

   If you use the default value of `latest`, then ksqlDB will read form the tail of the topics rather than the beginning, which means streams and tables won't have all the data you think they should.

3. Create a ksqlDB stream from `telemetry_stream` topic.

 ```

  CREATE STREAM telemetry_stream (
  player_id VARCHAR,
  event_type VARCHAR,
  timestamp BIGINT
) WITH (
  KAFKA_TOPIC='telemetry_events',
  VALUE_FORMAT=‘JSON’
);
 ```
4. Use the following statement to query `telemetry_stream ` stream to ensure it's being populated correctly.

   ```
   SELECT * FROM telemetry_stream EMIT CHANGES;
   ```

   Stop the running query by clicking on **Stop**.

   <div align="center"> 
  <img src="images/Stream_Data_Display.jpeg" width =100% heigth=100%>
</div>

5. Create `player_kill_ratio` table based on the `telemetry_stream` stream you just created.The table is updated in real-time every time a player kills or dies within a specific window. It is important to note that in this example, the tumbling window is set to 5 minutes, but you have the flexibility to choose your own window size.

 ```

 CREATE TABLE player_kill_ratio  with (kafka_topic = ‘player_kill_ratio’) AS
SELECT player_id,
       SUM(CASE WHEN event_type = 'kill' THEN 1 ELSE 0 END) as kill_count,
       SUM(CASE WHEN event_type = 'death' THEN 1 ELSE 0 END) as death_count,
       (SUM(CASE WHEN event_type = 'kill' THEN 1 ELSE 0 END) * 1.0) / NULLIF(SUM(CASE WHEN event_type = 'death' THEN 1 ELSE 0 END), 0) as kill_ratio
FROM telemetry_stream
WINDOW TUMBLING (SIZE 5 MINUTES)  -- Adjust the window size as needed
GROUP BY player_id
EMIT CHANGES;

```

6. Use the following statement to query `player_kill_ratio` table to ensure it's being populated correctly.

   ```SQL
   SELECT * FROM player_kill_ratio;
   ```

   Stop the running query by clicking on **Stop**.
<div align="center"> 
  <img src="images/Kill:Death-Output.jpeg" width =100% heigth=100%>
</div>


## Connect External System  to sink Enriched Events from  Confluent Cloud using Connector

You can create  Sink connector either through CLI or Confluent Cloud web UI.

<details>
    <summary><b>CLI</b></summary>

1. Run the following command to create the  Sink connector.

   ```bash
   confluent connect cluster create --config-file confluent/connect_config.json
   ```

**Note:** Before executing the command, substitute the connect properties with the filename that you are using.

</details>
<br>

<details>
    <summary><b>Confluent Cloud Web UI</b></summary>

1. On the navigation menu, select **Connectors** and **+ Add connector**.
1. In the search bar search for your connector and select the connector.
1. Create a new  Sink connector and complete the required fields.

</details>
<br>

Once the connector is in **Running** state navigate to your database/external system and verify messages are showing up correctly.

Refer to our [documentation](https://www.confluent.io/product/connectors/) for detailed instructions about the  connector that are available.

## Congratulations

By utilizing SQL-like commands, we have developed a real-time telemetry event processing system that calculates the kill ratio for each player in real-time. This system can send the results directly back to the game server, improving the overall user experience or to other external systems.With this system, we can process and analyze data in real-time, allowing for better decision-making and driving better business outcomes.

# Teardown

You want to delete any resources that were created during the demo so you don't incur additional charges.


## Python Script

Go back to the terminal window where the [mock_data_generator.py](./python//mock_data_generator.py) is running and quit with `Ctrl+C`.

## Infrastructure

1. Run the following command to delete all resources created by Terraform
   ```bash
   terraform apply -destory

## Confluent Cloud Stream Governance

Confluent offers data governance tools such as Stream Quality, Stream Catalog, and Stream Lineage in a package called Stream Governance. These features ensure your data is high quality, observable and discoverable. Learn more about **Stream Governance** [here](https://www.confluent.io/product/stream-governance/) and refer to the [docs](https://docs.confluent.io/cloud/current/stream-governance/overview.html) page for detailed information.

1.  Navigate to https://confluent.cloud
1.  Use the left hand-side menu and click on **Stream Lineage**.
    Stream lineage provides a graphical UI of the end to end flow of your data. Both from the a bird’s eye view and drill-down magnification for answering questions like:

    - Where did data come from?
    - Where is it going?
    - Where, when, and how was it transformed?

In our use case, the stream lineage appears as follows: we utilize a Python script to generate events that are sent to the telemetry topic. These events are then enriched on the stream with the assistance of a KTable, where the kill-to-death ratio is calculated.


<div align="center"> 
  <img src="images/goverance.jpeg" width =100% heigth=100%>
</div>
   


# References

1. Connectors for Confluent Cloud [doc](https://docs.confluent.io/platform/current/connect/index.html)

2. Peering Connections in Confluent Cloud [doc](https://docs.confluent.io/cloud/current/networking/peering/index.html)
3. ksqlDB [page](https://www.confluent.io/product/ksqldb/) and [use cases](https://developer.confluent.io/tutorials/#explore-top-use-cases)
4. Stream Governance [page](https://www.confluent.io/product/stream-governance/) and [doc](https://docs.confluent.io/cloud/current/stream-governance/overview.html)

  
