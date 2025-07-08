# jiraAutomation-aws-gcp

Background:
This is a repo for creating a passwordless connection from a Jira Automation to a Google Cloud Platform Pub/Sub. 

Problem Statement:
Jira Automation natively supports connecting to various AWS Services (SNS, Systems Manager) - but does not provide a native connection to GCP. Secrets management in Jira Automation is imperfect - and no way to create a specific OIDC principal and JWT exists in Jira Automation.

Solution:

This solution uses the following tools to create this integration:

1) Follow the instructions here to create the neccesary resources.
https://support.atlassian.com/cloud-automation/docs/configure-aws-sns-for-jira-automation/ - describes the process to create the AWS Role.

in this Repo - the core AWS components outlined by Atlassian (AWS SNS Topic, Topic Policy) are created via Terraform.

2) AWS SNS -> Lambda

The AWS SNS Topic triggers a new Lambda Function. This new Lambda function will also need an AWS Role with related permissions. In this example the Lambda function is written in Python - and requires a Requests Layer.

This is provided in Terraform.

3) GCP Pub/Sub and Workload Identity Federation Principal

In GCP we will need:
a) A Pub/Sub topic
b) a Workload Identity Federation Pool and Provider with a mapped Principal
c) a new IAM binding for the Workload Identity Federation Principal to the Pub/Sub permissions.

This is provided in Terraform.

4) Lambda Function

The Lambda function triggered by SNS is provided here in Python with a mandatory Requests layer. This users the Boto3 signature method to:
a) create a named role session.
b) create a GCP accpetable token.
c) exchange that token for a GCP identity token from GCP STS.
d) create a call to GCP Pub/Sub and post the retrieval timestamp and the payload retrieved by the Lambda from the SNS.

Additional integrations (pulling the ticket/changelog/jira needs) are left up the end users needs in GCP. This does not create an integration out to Jira. 