import os
import json
import sys
import traceback
from mangum import Mangum
from app.main import app, logger

# Set environment variables for Lambda
os.environ.setdefault("AWS_LAMBDA_FUNCTION_NAME", "passwordsupport-api")

# Create Mangum handler
mangum_handler = Mangum(app, lifespan="off")

# Lambda handler function
def lambda_handler(event, context):
    try:
        # Print the incoming event for debugging
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Check if required environment variables are set
        required_vars = ["SECRET_KEY", "FERNET_KEY", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
        for var in required_vars:
            if not os.getenv(var):
                logger.error(f"Missing required environment variable: {var}")
        
        # Call the Mangum handler
        response = mangum_handler(event, context)
        logger.info(f"Response: {json.dumps(response)}")
        return response
    except Exception as e:
        # Log the full exception traceback
        exception_type = e.__class__.__name__
        exception_message = str(e)
        exc_info = sys.exc_info()
        stack_trace = traceback.format_exception(*exc_info)
        
        logger.error(f"Exception Type: {exception_type}")
        logger.error(f"Exception Message: {exception_message}")
        logger.error(f"Stack Trace: {''.join(stack_trace)}")
        
        # Return a formatted error response
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,Authorization",
                "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS"
            },
            "body": json.dumps({
                "error": "Internal server error",
                "type": exception_type,
                "message": exception_message
            })
        }