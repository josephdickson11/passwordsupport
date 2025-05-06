FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.10

# Copy requirements file
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pip install -r requirements.txt

# Copy function code
COPY app/ ${LAMBDA_TASK_ROOT}/app/
COPY lambda_handler.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (this is the correct format for Lambda container images)
CMD [ "lambda_handler.lambda_handler" ]
