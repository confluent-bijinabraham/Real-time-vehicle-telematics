#This part creates environment
resource "confluent_environment" "development" {
  display_name = "Development"

  lifecycle {
    prevent_destroy = true
  }
}


#This part creates cluster inside environment
resource "confluent_kafka_cluster" "basic" {
  display_name = "Terraform"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-east-2"
  basic {}

  environment {
    
  id=confluent_environment.development.id
  }

  lifecycle {
    prevent_destroy = true
  }
}

##This part creates service account

resource "confluent_service_account" "terraform_user" {
  display_name = "terraform_user"
  description  = "terraform created"
}

##This part assigned role to the user  account created
resource "confluent_role_binding" "terraform_user-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.terraform_user.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

# This part creates API Key for service account
resource "confluent_api_key" "terraform_Created_APIKEY" {
  display_name = "terraform_Created_APIKEY-kafka-api-key"
  description  = "Kafka API Key that is owned by 'terraform_user' service account"
  owner {
    id          = confluent_service_account.terraform_user.id
    api_version = confluent_service_account.terraform_user.api_version
    kind        = confluent_service_account.terraform_user.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
     id = confluent_environment.development.id
     
    }
  }
    
  
  

 
}
   

# This part creates a topic 

resource "confluent_kafka_topic" "telemetry_events" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "telemetry_events"
  rest_endpoint      = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key   = confluent_api_key.terraform_Created_APIKEY.id
    secret = confluent_api_key.terraform_Created_APIKEY.secret
  }
}

  
resource "confluent_ksql_cluster" "example" {
  display_name = "example"
  csu          = 4
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  credential_identity {
    id = confluent_service_account.terraform_user.id
  }
  environment {
    id = confluent_environment.development.id
     
  }
  


  lifecycle {
    prevent_destroy = true
  }
}
