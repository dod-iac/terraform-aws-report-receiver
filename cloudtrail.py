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
        uncompressed = gzip.decompress(base64.b64decode(data))
        dat = json.loads(uncompressed)
        for rec in dat:
            print(rec)
        print(dat["logEvents"])
        for rec in dat["logEvents"]:
            msg = json.loads(rec["message"])
            msg["owner"] = dat["owner"]
            msg["logGroup"] = dat["logGroup"]
            msg["project"] = project
            msg["streamname"] = streamName

            out.append({'Data': json.dumps(msg)})


    client = boto3.client('firehose')
    result = client.put_record_batch(
    DeliveryStreamName=streamName,
    Records=out
    )
    print(result)
