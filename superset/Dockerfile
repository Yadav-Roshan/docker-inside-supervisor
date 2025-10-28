FROM apache/superset:latest

# Switch to root user to install packages
USER root

# Install curl (for health checks) and gosu (to run the app as a non-root user)
RUN apt-get update && apt-get install -y curl gosu && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

# The official image creates a 'superset' user. We'll ensure our app runs as this user.
# The entrypoint script itself will start as root (PID 1) and then use gosu
# to drop privileges for the application process.

ENTRYPOINT ["/app/entrypoint.sh"]