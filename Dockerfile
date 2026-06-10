FROM node:18-alpine

# Create app directory
WORKDIR /app

# Copy package.json and npm-shrinkwrap.json (from genieacs-src directory)
COPY genieacs-src/package.json genieacs-src/npm-shrinkwrap.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy custom bin and public assets
COPY genieacs-src/bin/ ./bin/
COPY genieacs-src/public/ ./public/

# Setup log directory and create permissions
RUN mkdir -p /var/log/genieacs && \
    chmod 777 /var/log/genieacs

# Setup global executable links for the GenieACS binaries
RUN ln -s /app/bin/genieacs-cwmp /usr/local/bin/genieacs-cwmp && \
    ln -s /app/bin/genieacs-ui /usr/local/bin/genieacs-ui && \
    ln -s /app/bin/genieacs-nbi /usr/local/bin/genieacs-nbi && \
    ln -s /app/bin/genieacs-fs /usr/local/bin/genieacs-fs

# Default execution path (containers override this via command in compose)
CMD ["genieacs-cwmp"]
