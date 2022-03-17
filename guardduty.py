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
        uncompressed = None
        #guard duty occasionally compresses things, but not always
        #probably should check magic number if available, but ideally without external library
        try:
            uncompressed = gzip.decompress(base64.b64decode(data))
        except:
            pass
        if uncompressed is None:
            dat = json.loads(base64.b64decode(data))
        else:
            dat = json.loads(uncompressed)


        dat["project"] = project
        if(dat.get("detail") is not None):
            if(dat["detail"].get("severity") is not None):
                severity = float(dat["detail"]["severity"])

                if severity >= 9:
                    severitylevel = "CRITICAL"
                if severity <9 and severity>=7:
                    severitylevel = "HIGH"
                if severity <7 and severity>=4:
                    severitylevel = "MEDIUM"
                if severity < 4:
                    severitylevel = "LOW"
                dat["detail"]["severitylevel"] = severitylevel
                dat["_id"] = dat["detail"]["id"]
        out.append({'Data': json.dumps(dat)})

    print("publishing to {}".format(streamName))
    client = boto3.client('firehose')
    result = client.put_record_batch(
    DeliveryStreamName=streamName,
    Records=out
    )
    print(result)
