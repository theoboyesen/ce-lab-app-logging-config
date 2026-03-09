# Deploy Application with Logging Configuration

## Overview

This lab demonstrates how to implement structured logging for a web application and ship logs to AWS CloudWatch for centralized monitoring and analysis. A Flask API was deployed on an EC2 instance and configured to produce structured JSON logs using the `structlog` library. The logs are written to a local log file and collected by the Amazon CloudWatch Agent, which forwards them to CloudWatch Logs. Logs can then be queried and analyzed using CloudWatch Logs Insights.

This setup provides basic observability for the application, allowing events such as requests, health checks, and order creation to be monitored in real time.

---

## Architecture

* **Application:** Flask API with structured JSON logging using `structlog`
* **Infrastructure:** EC2 instance running Ubuntu
* **Logging:** Application logs written to `application.log`
* **Agent:** Amazon CloudWatch Agent shipping logs to CloudWatch
* **Log Storage:** Amazon CloudWatch Logs log group `/aws/application/api`
* **Analysis:** CloudWatch Logs Insights queries used to analyze application events

High-level flow:

Application → Local Log File → CloudWatch Agent → CloudWatch Logs → Logs Insights

---

## Setup & Deployment

### 1. Provision EC2 Instance

An EC2 instance was created using Terraform with the following components:

* Ubuntu AMI
* Security group allowing SSH and port 5000
* SSH key pair for remote access

SSH into the instance:

```
ssh -i terraform-key.pem ubuntu@<EC2_PUBLIC_IP>
```

---

### 2. Install Required Packages

Update the system and install Python dependencies:

```
sudo apt update
sudo apt install python3 python3-pip wget -y
```

---

### 3. Create the Application

Create the application directory:

```
mkdir app
cd app
```

Create `server.py` with a Flask API that logs events in JSON format using `structlog`.

Create `requirements.txt`:

```
flask
structlog
boto3
```

Install dependencies:

```
pip3 install -r requirements.txt
```

---

### 4. Run the Application with File Logging

Start the Flask server and redirect output to a log file:

```
nohup python3 server.py >> application.log 2>&1 &
```

This ensures logs are written to `application.log`, which will be read by the CloudWatch agent.

---

### 5. Install CloudWatch Agent

Download and install the agent:

```
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
```

---

### 6. Configure CloudWatch Agent

Create the configuration file:

```
sudo nano /opt/aws/amazon-cloudwatch-agent/etc/config.json
```

Configuration used:

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ubuntu/app/application.log",
            "log_group_name": "/aws/application/api",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
```

Start the agent:

```
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config \
-m ec2 \
-s \
-c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

---

### 7. Generate Logs

Send requests to the API:

```
curl http://<EC2_PUBLIC_IP>:5000/
curl http://<EC2_PUBLIC_IP>:5000/health
```

Create order events:

```
curl -X POST http://<EC2_PUBLIC_IP>:5000/order \
-H "Content-Type: application/json" \
-d '{"amount": 99.99, "items": 3, "user_id": "user-123"}'
```

These requests generate structured logs that appear in CloudWatch.

---

### 8. Verify Logs in CloudWatch

Navigate to:

CloudWatch → Logs → Log Groups → `/aws/application/api`

Verify that log streams are being created and events are appearing.

---

## Example Logs Insights Queries

View recent events:

```
fields @timestamp, @message
| sort @timestamp desc
| limit 20
```

Find order creation events:

```
fields @timestamp, event
| filter event = "order_created"
| sort @timestamp desc
```

Count events by type:

```
fields event
| stats count() by event
| sort count() desc
```

---

## Screenshots

The following screenshots are included in the repository:

* CloudWatch log group `/aws/application/api`
* Log stream showing structured JSON logs
* Logs Insights query results demonstrating log analysis
* Running Flask application on EC2

---

## Challenges & Solutions

**1. Logs not appearing in CloudWatch**

Initially, logs were visible in the terminal but not in CloudWatch. This occurred because the application was started normally (`python3 server.py`), which outputs logs only to the console.

**Solution:**
The application was restarted with output redirected to a file:

```
python3 server.py >> application.log 2>&1
```

This allowed the CloudWatch Agent to read logs from `application.log`.

---

**2. CloudWatch Agent permissions**

Logs were not appearing initially due to missing IAM permissions.

**Solution:**
An IAM role with the `CloudWatchAgentServerPolicy` was attached to the EC2 instance, allowing it to create log groups and publish log events.

---

**3. Logs Insights queries returning no results**

Queries filtering for `order_created` events initially returned no results because no order requests had been generated.

**Solution:**
POST requests were sent to the `/order` endpoint to generate relevant log events for analysis.

---

## Result

This lab successfully implemented centralized logging and observability for an EC2-hosted application using:

* Structured JSON logging
* Amazon CloudWatch Logs
* CloudWatch Agent
* CloudWatch Logs Insights

The setup enables efficient monitoring, debugging, and analysis of application behavior in a production-style environment.

# Submission