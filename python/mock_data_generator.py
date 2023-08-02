# Uses the CTA Bus Tracker API (documentation available here):
# https://www.transitchicago.com/assets/1/6/cta_Bus_Tracker_API_Developer_Guide_and_Documentation_20160929.pdf

# Given a list of Route Designators ('rt' below), return Vehicle IDs
# JSON response will be most recent status for each vehicle

# Take that JSON response and send it Confluent Kafka REST Proxy

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
