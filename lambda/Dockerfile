FROM public.ecr.aws/lambda/python:3.12

# Install uv
RUN pip install uv

# Copy pyproject.toml and install dependencies
COPY pyproject.toml .
RUN uv pip install . --target ${LAMBDA_TASK_ROOT}

# Copy your handler code
COPY src/ ${LAMBDA_TASK_ROOT}/

# Set the CMD to your handler
CMD ["index.handler"] 
