import boto3
import base64
import gzip
import json
import boto3
from os import getenv
def lambda_handler(event, context):
    streamName = getenv("DELIVERYSTREAM")
    project = getenv("PROJECT")
    out = []
    for record in event['Records']:
        data = record["kinesis"]["data"]
        uncompressed = base64.b64decode(data)
        dat = json.loads(uncompressed)
        print(dat)
        dat["project"] = project
        out.append({'Data': json.dumps(dat)})

    print("publishing to {}".format(streamName))
    client = boto3.client('firehose')
    result = client.put_record_batch(
    DeliveryStreamName=streamName,
    Records=out
    )
    print(result)
