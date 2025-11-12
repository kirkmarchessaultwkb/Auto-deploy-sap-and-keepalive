FROM node:14-alpine

# Install dependencies
RUN apk add --no-cache bash curl unzip ca-certificates

# Set working directory
WORKDIR /app

# Copy application files
COPY package.json ./
COPY index.js ./
COPY start.sh ./

# Make start.sh executable
RUN chmod +x start.sh

# Install Node.js dependencies (if any)
RUN npm install --production

# Create necessary directories
RUN mkdir -p /root/.npm/logs /root/.npm/pids

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Start the application
CMD ["npm", "start"]
