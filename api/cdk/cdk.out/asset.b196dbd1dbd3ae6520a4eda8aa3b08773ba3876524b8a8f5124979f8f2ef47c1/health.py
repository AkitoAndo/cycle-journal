"""Health check handler."""

import json
import os
from datetime import datetime


def handler(event, context):
    """Health check endpoint."""
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps({
            "status": "healthy",
            "stage": os.environ.get("STAGE", "unknown"),
            "timestamp": datetime.utcnow().isoformat(),
        }),
    }
