# Real-time vehicle telematics

From locomotive analytics companies tracking predictive maintenance data from their trains, to digital-native companies tracking semi-trailer trucks movement data across America’s highways, or municipalities using 100’s of buses to move people around their city. Confluence has seen it all when it comes to collecting IoT data. IoT-centric companies are struggling to collect IoT data in order to optimize fleet management, reduce operating costs, improve safety and compliance, and enhance the customer experience.

One thing remains the same – all of these companies rely on 1 too many IoT devices(commonly 1,000s to 100,000s) to collect high volumes of data to a central repository in the cloud for processing, warehousing, and delivery back to their platform applications. The hunger for consuming and delivering this real-time data has reached an all-time high. 

This demo guides you through the process of utilizing telemetry events to extract user insights using confluent kafka.

## Architecture Diagram

This demo makes use of a Python data generator script to transmit real-time IOT events from the CTA buses API to Confluent Cloud. The events are then processed through KSQLDB, where they are enriched to perform transformations on the data. The enriched data can be sent to any external system of your choice for further analysis using a connector plugin.

<div align="center"> 
  <img src="images/RT metrics architecture.jpeg" width =100% heigth=100%>
</div>



# Requirements

In order to successfully complete this demo you need to install a few tools before getting started.

- If you don't have a Confluent Cloud account, sign up for a free trial [here](https://www.confluent.io/confluent-cloud/tryfree).
- Install Confluent Cloud CLI by following the instructions [here](https://docs.confluent.io/confluent-cli/current/install.html).
- Please follow the instructions to install Terraform if it is not already installed on your system.[here](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  
- This demo uses Python 3.9.13 version.
- This demo uses Python modules. You can install this module through `pip`.
  ```
  pip3 install modulename
  ```

## Prerequisites

### Confluent Cloud

1. Sign up for a Confluent Cloud account [here](https://www.confluent.io/get-started/).
1. After verifying your email address, access Confluent Cloud sign-in by navigating [here](https://confluent.cloud).
1. When provided with the _username_ and _password_ prompts, fill in your credentials.

   > **Note:** If you're logging in for the first time you will see a wizard that will walk you through some tutorials. Minimize this as you will walk through these steps in this guide.

1. Create Confluent Cloud API keys by following the steps in UI. Click on the button that is present on the right top section and click on Cloud API Key.
<div align="center"> 
  <img src="images/CloudUI.png" width =100% heigth=100%>
</div>

 Now Click Add Key to generate API keys and store them as we will be using that key in this demo.
 <div align="center"> 
  <img src="images/cloud2.jpeg" width =100% heigth=100%>
</div>
    
   > **Note:** This is different than Kafka cluster API keys.

## Setup

1. This demo uses Terraform  to spin up resources that are needed.

2. Update the `terraform/variables.tf` file for the following variables with your Cloud API credentials.

```
variable "confluent_cloud_api_key" {
  
  default = " Replace with your API Key"   
}

variable "confluent_cloud_api_secret" {
  default = "Replace with your API secret"   
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

Please run the Python script located in the Python script folder. Before running it, make sure to replace the below mentioned configuration settings in the code to point to the Confluent Cloud cluster that you created.
    
```
'bootstrap.servers': ''  # Replace with your Confluent Cloud bootstrap servers
'sasl.username': ''      # Replace with your Confluent Cloud API key
'sasl.password': ''      # Replace with your Confluent Cloud API secret
```
To obtain the following details, navigate to the Clients section on the Confluent Cloud UI and select Python as the script type. From there, you can copy the bootstrap server and API Key details and replace them in the code.

```
# Uses the CTA Bus Tracker API (documentation available here):
# https://www.transitchicago.com/assets/1/6/cta_Bus_Tracker_API_Developer_Guide_and_Documentation_20160929.pdf

# Given a list of Route Designators ('rt' below), return Vehicle IDs
# JSON response will be the most recent status for each vehicle

# Take that JSON response and send it to Confluent Kafka REST Proxy

import requests
import json
from configparser import ConfigParser
from ruamel.yaml import YAML
yaml = YAML()
import time
from confluent_kafka import Producer

p = Producer({
    'bootstrap.servers': '', # Replace with your Confluent Cloud bootstrap servers
    'sasl.mechanism': 'PLAIN', 
    'security.protocol': 'SASL_SSL',
    'sasl.username': '', # Replace with your Confluent Cloud API key
    'sasl.password': ''  # Replace with your Confluent Cloud API secret

})

#Topic to be used in CC 
topic = 'cta_buses'

# CTA Bus Tracker API values
api_key = '' # Replace with your CTS Bus Tracker API key
getvehicles_url = 'http://ctabustracker.com/bustime/api/v2/getvehicles'

# Format the API request and parse the response
vehicle_params = {'key': api_key, 'format': 'json', 'rt': 'X9,11,12,J14,15,18,19,20,21,22', 'tmres': 's'}

while True:
    r_vehicles = requests.get(getvehicles_url, params=vehicle_params)
    # each JSON object is the latest stats for each vehicle ID (bus).
    response_dict = r_vehicles.json()
    vehicle_dict = response_dict['bustime-response']
    list_of_vids = vehicle_dict['vehicle']


    for vid in list_of_vids:
        # each vid is a dict
        list_of_records = []
        kafka_record = {}
        kafka_record['value'] = vid
        # use the vehicle ID - vid as the key for each record
        kafka_record['key'] = vid["vid"]
        list_of_records.append(kafka_record)
        send_data = {}
        send_data['records'] = list_of_records
        send_json = json.dumps(send_data)
        print(send_json)
        p.produce(topic, key=vid["vid"], value=json.dumps(vid))
        p.poll(0)
    p.flush(10) 

    time.sleep(5)
```
Please run the Python script using the following syntax:

```
python mock_data_generator.py
```

## Connect External System to sink Enriched Events from  Confluent Cloud using Connector

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

  
